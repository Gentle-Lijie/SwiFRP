import Foundation

class ConfigFileManager {
    static let shared = ConfigFileManager()

    private let fm = FileManager.default
    private let converter = ConfigConverter()

    private init() {
        try? AppPaths.ensureDirectoriesExist()
    }

    // MARK: - App Config

    func loadAppConfig() -> AppConfig {
        let url = AppPaths.appConfigURL
        guard let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func saveAppConfig(_ config: AppConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: AppPaths.appConfigURL, options: .atomic)
    }

    // MARK: - Client Configs

    func loadAllConfigs(sortOrder: [String] = []) -> [ClientConfig] {
        let dir = AppPaths.configDirectory
        guard let files = try? fm.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return [] }

        var configs: [ClientConfig] = []
        for file in files {
            let ext = file.pathExtension.lowercased()
            guard ext == "toml" || ext == "ini" else { continue }
            guard let content = try? String(contentsOf: file, encoding: .utf8) else { continue }
            let name = file.deletingPathExtension().lastPathComponent
            let config: ClientConfig
            if ext == "ini" {
                config = converter.iniToConfig(content, name: name)
            } else {
                config = converter.tomlToConfig(content, name: name)
            }
            configs.append(config)
        }

        if !sortOrder.isEmpty {
            configs.sort { a, b in
                let idxA = sortOrder.firstIndex(of: a.name) ?? Int.max
                let idxB = sortOrder.firstIndex(of: b.name) ?? Int.max
                return idxA < idxB
            }
        }
        return configs
    }

    func saveConfig(_ config: ClientConfig) {
        let url = AppPaths.configURL(for: config.name, legacyFormat: config.legacyFormat)
        let content: String
        if config.legacyFormat {
            content = converter.configToINI(config)
        } else {
            content = converter.configToTOML(config)
        }
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    func deleteConfig(name: String) {
        // Remove both possible config formats
        let tomlURL = AppPaths.configURL(for: name, legacyFormat: false)
        let iniURL = AppPaths.configURL(for: name, legacyFormat: true)
        try? fm.removeItem(at: tomlURL)
        try? fm.removeItem(at: iniURL)

        // Remove associated log files
        let logFiles = FileUtils.logFilesForConfig(name: name)
        for logFile in logFiles {
            try? fm.removeItem(at: logFile)
        }
    }

    func configExists(name: String) -> Bool {
        let tomlURL = AppPaths.configURL(for: name, legacyFormat: false)
        let iniURL = AppPaths.configURL(for: name, legacyFormat: true)
        return fm.fileExists(atPath: tomlURL.path) || fm.fileExists(atPath: iniURL.path)
    }

    func configFileURL(for name: String) -> URL {
        let iniURL = AppPaths.configURL(for: name, legacyFormat: true)
        if fm.fileExists(atPath: iniURL.path) {
            return iniURL
        }
        return AppPaths.configURL(for: name, legacyFormat: false)
    }

    // MARK: - Import

    func importConfigFromFile(at url: URL) throws -> ClientConfig {
        let ext = url.pathExtension.lowercased()
        let content = try String(contentsOf: url, encoding: .utf8)
        let name = url.deletingPathExtension().lastPathComponent

        switch ext {
        case "toml":
            return converter.tomlToConfig(content, name: name)
        case "ini":
            return converter.iniToConfig(content, name: name)
        case "json", "yml", "yaml":
            // For JSON/YAML, attempt to detect as TOML or INI fallback
            let format = converter.detectFormat(content)
            if format == .ini {
                return converter.iniToConfig(content, name: name)
            }
            return converter.tomlToConfig(content, name: name)
        default:
            throw ConfigFileError.unsupportedFormat(ext)
        }
    }

    func importConfigFromURL(_ url: URL) async throws -> ClientConfig {
        let data = try await NetworkUtils.fetchURL(url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw ConfigFileError.invalidContent
        }

        let name = url.deletingPathExtension().lastPathComponent
        let format = converter.detectFormat(content)
        if format == .ini {
            return converter.iniToConfig(content, name: name)
        }
        return converter.tomlToConfig(content, name: name)
    }

    func importConfigFromClipboard(_ base64String: String) throws -> ClientConfig {
        guard let decoded = StringUtils.base64Decode(base64String) else {
            throw ConfigFileError.invalidContent
        }

        let name = StringUtils.generateRandomName()
        let format = converter.detectFormat(decoded)
        if format == .ini {
            return converter.iniToConfig(decoded, name: name)
        }
        return converter.tomlToConfig(decoded, name: name)
    }

    func importConfigsFromZIP(at url: URL) throws -> [ClientConfig] {
        let extractedFiles = try FileUtils.importFromZIP(at: url)
        var configs: [ClientConfig] = []
        for file in extractedFiles {
            if let config = try? importConfigFromFile(at: file) {
                configs.append(config)
            }
        }
        return configs
    }

    // MARK: - Export

    func exportConfig(_ config: ClientConfig, to url: URL) throws {
        let content: String
        if config.legacyFormat {
            content = converter.configToINI(config)
        } else {
            content = converter.configToTOML(config)
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func exportAllAsZIP(configs: [ClientConfig], to url: URL) throws {
        var configURLs: [URL] = []
        for config in configs {
            let fileURL = configFileURL(for: config.name)
            if fm.fileExists(atPath: fileURL.path) {
                configURLs.append(fileURL)
            }
        }
        try FileUtils.exportAllAsZIP(configs: configURLs, to: url)
    }

    // MARK: - Share Link

    func generateShareLink(_ config: ClientConfig) -> String {
        let content: String
        if config.legacyFormat {
            content = converter.configToINI(config)
        } else {
            content = converter.configToTOML(config)
        }
        let encoded = StringUtils.base64Encode(content)
        return "frp://\(encoded)"
    }
}

// MARK: - Errors

enum ConfigFileError: LocalizedError {
    case unsupportedFormat(String)
    case invalidContent

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "Unsupported config format: \(ext)"
        case .invalidContent:
            return "Invalid or unreadable config content."
        }
    }
}
