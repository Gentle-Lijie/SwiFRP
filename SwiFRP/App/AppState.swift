import SwiftUI
import Combine

enum AppTab: String, CaseIterable {
    case configuration
    case log
    case preferences
    case about
}

class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedTab: AppTab = .configuration
    @Published var appConfig: AppConfig = AppConfig()
    @Published var configs: [ClientConfig] = []
    @Published var selectedConfigIndex: Int? = nil
    @Published var hasNewVersion: Bool = false
    @Published var isPasswordVerified: Bool = false

    var selectedConfig: ClientConfig? {
        guard let index = selectedConfigIndex, index >= 0, index < configs.count else { return nil }
        return configs[index]
    }

    private init() {
        loadAppConfig()
        loadConfigs()
        startStatusTracking()
    }
    
    private func startStatusTracking() {
        StatusTracker.shared.setTrackedConfigs(configs)
        StatusTracker.shared.startTracking()
    }

    func loadAppConfig() {
        appConfig = ConfigFileManager.shared.loadAppConfig()
        if appConfig.password.isEmpty {
            isPasswordVerified = true
        }
    }

    func loadConfigs() {
        configs = ConfigFileManager.shared.loadAllConfigs(sortOrder: appConfig.sort)
        StatusTracker.shared.setTrackedConfigs(configs)
    }

    func saveAppConfig() {
        ConfigFileManager.shared.saveAppConfig(appConfig)
    }

    func addConfig(_ config: ClientConfig) {
        configs.append(config)
        appConfig.sort.append(config.name)
        StatusTracker.shared.setTrackedConfigs(configs)
        saveAppConfig()
    }

    func removeConfig(at indices: IndexSet) {
        let names = indices.map { configs[$0].name }
        configs.remove(atOffsets: indices)
        appConfig.sort.removeAll { names.contains($0) }
        saveAppConfig()
        for name in names {
            ConfigFileManager.shared.deleteConfig(name: name)
        }
    }
}
