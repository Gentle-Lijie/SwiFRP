import Foundation

class ConfigFileManager {
    static let shared = ConfigFileManager()

    private let fileManager = FileManager.default

    private var configDirectory: URL {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return fileManager.temporaryDirectory.appendingPathComponent("SwiFRP", isDirectory: true)
        }
        return appSupport.appendingPathComponent("SwiFRP", isDirectory: true)
    }

    private var appConfigURL: URL {
        configDirectory.appendingPathComponent("app_config.json")
    }

    private init() {
        try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
    }

    func loadAppConfig() -> AppConfig {
        guard let data = try? Data(contentsOf: appConfigURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func saveAppConfig(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: appConfigURL, options: .atomic)
    }

    func loadAllConfigs(sortOrder: [String]) -> [ClientConfig] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: configDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        var configs: [ClientConfig] = []
        for file in files where file.pathExtension == "json" && file.lastPathComponent != "app_config.json" {
            if let data = try? Data(contentsOf: file),
               let config = try? JSONDecoder().decode(ClientConfig.self, from: data) {
                configs.append(config)
            }
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

    func deleteConfig(name: String) {
        let url = configDirectory.appendingPathComponent("\(name).json")
        try? fileManager.removeItem(at: url)
    }
}
