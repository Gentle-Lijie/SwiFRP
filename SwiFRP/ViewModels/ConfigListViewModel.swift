import SwiftUI
import Combine

class ConfigListViewModel: ObservableObject {
    @Published var selectedIndices: Set<Int> = []
    @Published var isShowingNewConfigDialog = false
    @Published var isShowingImportFileDialog = false
    @Published var isShowingImportURLDialog = false
    @Published var isShowingDeleteConfirmation = false
    @Published var isShowingExportDialog = false
    @Published var isShowingPropertiesDialog = false
    @Published var isShowingNATDialog = false
    @Published var editingConfig: ClientConfig? = nil
    @Published var errorMessage: String? = nil
    @Published var showError = false

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func createNewConfig() {
        var config = ClientConfig(name: "")
        let defaults = appState.appConfig.defaults
        config.serverPort = Constants.defaultServerPort
        config.natHoleSTUNServer = defaults.natHoleSTUNServer
        config.user = defaults.user
        config.logLevel = defaults.logLevel
        config.logMaxDays = defaults.logMaxDays
        config.dnsServer = defaults.dnsServer
        config.connectServerLocalIP = defaults.connectServerLocalIP
        config.tcpMux = defaults.tcpMux
        config.tlsEnable = defaults.tlsEnable
        config.manualStart = defaults.manualStart
        config.legacyFormat = defaults.legacyFormat
        config.protocol = defaults.protocol
        editingConfig = config
        isShowingNewConfigDialog = true
    }

    func saveConfig(_ config: ClientConfig) {
        if let existingIndex = appState.configs.firstIndex(where: { $0.name == config.name }) {
            appState.configs[existingIndex] = config
        } else {
            appState.addConfig(config)
        }
        ConfigFileManager.shared.saveConfig(config)
        editingConfig = nil
    }

    func deleteSelectedConfigs() {
        let sortedIndices = selectedIndices.sorted(by: >)
        var errors: [String] = []
        for index in sortedIndices {
            let config = appState.configs[index]
            do {
                try LaunchdManager.shared.uninstall(configName: config.name)
            } catch {
                errors.append("\(config.name): \(error.localizedDescription)")
            }
            ConfigFileManager.shared.deleteConfig(name: config.name)
        }
        appState.configs.remove(atOffsets: IndexSet(sortedIndices))
        appState.appConfig.sort = appState.configs.map { $0.name }
        appState.saveAppConfig()
        selectedIndices.removeAll()
        appState.selectedConfigIndex = nil
        if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
            showError = true
        }
    }

    func duplicateConfig(_ config: ClientConfig, fullCopy: Bool) {
        var newConfig = config
        var newName = config.name + "_copy"
        var counter = 1
        while appState.configs.contains(where: { $0.name == newName }) {
            counter += 1
            newName = config.name + "_copy\(counter)"
        }
        newConfig.name = newName
        if !fullCopy {
            newConfig.proxies = []
        }
        saveConfig(newConfig)
    }

    func moveConfig(from source: Int, direction: MoveDirection) {
        let target: Int
        switch direction {
        case .up: target = max(0, source - 1)
        case .down: target = min(appState.configs.count - 1, source + 1)
        case .top: target = 0
        case .bottom: target = appState.configs.count - 1
        }
        guard target != source else { return }
        appState.configs.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
        appState.appConfig.sort = appState.configs.map { $0.name }
        appState.saveAppConfig()
    }

    func importFromClipboard() {
        #if canImport(AppKit)
        guard let content = NSPasteboard.general.string(forType: .string) else {
            errorMessage = String(localized: "clipboard.empty")
            showError = true
            return
        }
        do {
            let config = try ConfigFileManager.shared.importConfigFromClipboard(content)
            saveConfig(config)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        #endif
    }

    func generateShareLink(for config: ClientConfig) -> String {
        return ConfigFileManager.shared.generateShareLink(config)
    }

    func exportAll() {
        isShowingExportDialog = true
    }
}

enum MoveDirection {
    case up, down, top, bottom
}
