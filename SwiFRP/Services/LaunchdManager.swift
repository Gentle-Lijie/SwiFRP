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
        return "/usr/local/bin/frpc"
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
        let label = serviceLabel(for: configName)
        _ = try runLaunchctl(["start", label])
    }

    func stop(configName: String) throws {
        let label = serviceLabel(for: configName)
        _ = try runLaunchctl(["stop", label])
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
        // Job loaded but no PID
        return .stopped
    }

    // MARK: - Plist Generation

    func generatePlist(config: ClientConfig, autoStart: Bool) -> [String: Any] {
        let label = serviceLabel(for: config.name)
        let configURL = AppPaths.configURL(for: config.name, legacyFormat: config.legacyFormat)
        let logURL = AppPaths.logURL(for: config.name)

        let keepAlive: Any = config.manualStart
            ? false
            : ["SuccessfulExit": false] as [String: Any]

        var plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [frpcPath, "-c", configURL.path],
            "RunAtLoad": autoStart,
            "KeepAlive": keepAlive,
            "StandardOutPath": logURL.path,
            "StandardErrorPath": logURL.path,
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
