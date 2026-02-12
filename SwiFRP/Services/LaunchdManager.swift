import Foundation

class LaunchdManager {
    static let shared = LaunchdManager()

    let bundleIdentifierPrefix = "com.swifrp.client."

    private let fm = FileManager.default

    private init() {}

    // MARK: - Identifiers & Paths

    func serviceLabel(for configName: String) -> String {
        bundleIdentifierPrefix + StringUtils.md5Hash(configName)
    }

    func plistURL(for configName: String) -> URL {
        let label = serviceLabel(for: configName)
        let launchAgentsDir = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try? fm.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)
        return launchAgentsDir.appendingPathComponent("\(label).plist")
    }

    // MARK: - frpc Binary

    private var frpcPath: String {
        // Check bundle Resources first
        if let bundlePath = Bundle.main.path(forResource: "frpc", ofType: nil) {
            return bundlePath
        }
        // Fall back to PATH lookup via /usr/bin/which
        if let path = try? runWhich("frpc"), !path.isEmpty {
            return path
        }
        // Check common locations
        let commonPaths = [
            "/usr/local/bin/frpc",
            "/opt/homebrew/bin/frpc",
            "\(fm.homeDirectoryForCurrentUser.path)/.local/bin/frpc"
        ]
        for path in commonPaths {
            if fm.fileExists(atPath: path) {
                return path
            }
        }
        return "/usr/local/bin/frpc"
    }
    
    /// Check if frpc binary exists
    var frpcExists: Bool {
        let path = frpcPath
        return fm.fileExists(atPath: path)
    }

    private func runWhich(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Install / Uninstall

    func install(config: ClientConfig, autoStart: Bool = false) throws {
        let plistDict = generatePlist(config: config, autoStart: autoStart)
        let plistData = try PropertyListSerialization.data(
            fromPropertyList: plistDict, format: .xml, options: 0
        )
        let url = plistURL(for: config.name)
        try plistData.write(to: url, options: .atomic)

        let label = serviceLabel(for: config.name)
        _ = try runLaunchctl(["load", "-w", url.path])

        if autoStart {
            _ = try? runLaunchctl(["start", label])
        }
    }

    func uninstall(configName: String) throws {
        let url = plistURL(for: configName)
        if fm.fileExists(atPath: url.path) {
            _ = try? runLaunchctl(["unload", "-w", url.path])
            try fm.removeItem(at: url)
        }
    }

    // MARK: - Start / Stop

    func start(configName: String) throws {
        // If service is not loaded, load it first
        let url = plistURL(for: configName)
        if !isLoaded(configName: configName) && fm.fileExists(atPath: url.path) {
            _ = try runLaunchctl(["load", "-w", url.path])
        }
        
        let label = serviceLabel(for: configName)
        _ = try runLaunchctl(["start", label])
    }
    
    private func isLoaded(configName: String) -> Bool {
        let label = serviceLabel(for: configName)
        guard let output = try? runLaunchctl(["list", label]) else { return false }
        return !output.contains("Could not find service")
    }

    func stop(configName: String) throws {
        // First, unload the service
        let url = plistURL(for: configName)
        if fm.fileExists(atPath: url.path) {
            _ = try? runLaunchctl(["unload", "-w", url.path])
        }
        
        // Then, kill any remaining frpc processes for this config
        killProcess(configName: configName)
    }
    
    private func killProcess(configName: String) {
        let configURL = AppPaths.configURL(for: configName, legacyFormat: false)
        let configPath = configURL.path
        
        // Find and kill frpc process using this config
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "frpc.*\(configPath)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // Parse PIDs and kill them
            for line in output.components(separatedBy: .newlines) {
                if let pid = Int(line.trimmingCharacters(in: .whitespaces)) {
                    // Try SIGTERM first
                    let kill = Process()
                    kill.executableURL = URL(fileURLWithPath: "/bin/kill")
                    kill.arguments = ["-TERM", "\(pid)"]
                    try? kill.run()
                    kill.waitUntilExit()
                    
                    // Wait a bit, then force kill if still running
                    Thread.sleep(forTimeInterval: 1.0)
                    if isProcessRunning(pid: pid) {
                        let forceKill = Process()
                        forceKill.executableURL = URL(fileURLWithPath: "/bin/kill")
                        forceKill.arguments = ["-KILL", "\(pid)"]
                        try? forceKill.run()
                        forceKill.waitUntilExit()
                    }
                }
            }
        } catch {
            print("Failed to kill process: \(error)")
        }
    }
    
    private func isProcessRunning(pid: Int) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/kill")
        process.arguments = ["-0", "\(pid)"]
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    func restart(configName: String) throws {
        let url = plistURL(for: configName)
        if fm.fileExists(atPath: url.path) {
            _ = try runLaunchctl(["unload", "-w", url.path])
            Thread.sleep(forTimeInterval: 1.0)
            _ = try runLaunchctl(["load", "-w", url.path])
            _ = try runLaunchctl(["start", serviceLabel(for: configName)])
        }
    }

    // MARK: - Status

    func isRunning(configName: String) -> Bool {
        let label = serviceLabel(for: configName)
        guard let output = try? runLaunchctl(["list", label]) else { return false }
        // If launchctl list <label> succeeds, the job is loaded; check for PID
        return !output.isEmpty && !output.contains("Could not find service")
    }

    func queryStatus(configName: String) -> ConfigState {
        let label = serviceLabel(for: configName)
        guard let output = try? runLaunchctl(["list", label]) else { return .unknown }

        if output.contains("Could not find service") {
            return .stopped
        }

        // Parse JSON-like output from launchctl list <label>
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("\"PID\"") || trimmed.hasPrefix("\"pid\"") {
                // Has a PID → running
                return .started
            }
        }
        // Job loaded but no PID - check actual process
        if getProcessPID(configName: configName) != nil {
            return .started
        }
        return .stopped
    }
    
    /// Gets the PID of running frpc process for a config
    func getProcessPID(configName: String) -> Int? {
        let configURL = AppPaths.configURL(for: configName, legacyFormat: false)
        let configPath = configURL.path
        
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "frpc.*\(configPath)"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if let pid = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return pid
            }
        } catch {}
        return nil
    }
    
    /// Gets the last error message from launchd if service failed to start
    func getServiceError(configName: String) -> String? {
        let label = serviceLabel(for: configName)
        guard let output = try? runLaunchctl(["list", label]) else { return nil }
        
        // Parse exit code
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("\"LastExitStatus\"") {
                if let range = trimmed.range(of: "="),
                   let endRange = trimmed.range(of: ";", range: range.upperBound..<trimmed.endIndex) {
                    let code = trimmed[range.upperBound..<endRange.lowerBound]
                        .trimmingCharacters(in: .whitespaces)
                    if let exitCode = Int(code), exitCode != 0 {
                        return "Service exited with code \(exitCode). Check logs for details."
                    }
                }
            }
        }
        
        // Check if PID is missing (service not running)
        if !output.contains("\"PID\"") && !output.contains("Could not find service") {
            return "Service loaded but not running. Check configuration and frpc binary."
        }
        
        return nil
    }

    // MARK: - Plist Generation

    func generatePlist(config: ClientConfig, autoStart: Bool) -> [String: Any] {
        let label = serviceLabel(for: config.name)
        let configURL = AppPaths.configURL(for: config.name, legacyFormat: config.legacyFormat)
        let logURL = AppPaths.logURL(for: config.name)

        // Don't use KeepAlive - we want manual control over starting/stopping
        // Add environment variable to disable colored output
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [frpcPath, "-c", configURL.path],
            "RunAtLoad": autoStart,
            "KeepAlive": false,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
            "EnvironmentVariables": ["NO_COLOR": "1", "TERM": "dumb"]
        ]

        return plist
    }

    // MARK: - Shell Helper

    @discardableResult
    private func runLaunchctl(_ arguments: [String]) throws -> String {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
