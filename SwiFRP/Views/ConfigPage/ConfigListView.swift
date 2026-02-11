import SwiftUI

struct ConfigListView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: ConfigListViewModel
    @ObservedObject private var statusTracker = StatusTracker.shared

    var body: some View {
        VStack(spacing: 0) {
            configList
            Divider()
            toolbar
        }
        .sheet(isPresented: $viewModel.isShowingNewConfigDialog) {
            if let config = viewModel.editingConfig {
                ConfigEditPlaceholder(config: config) { saved in
                    viewModel.saveConfig(saved)
                }
            }
        }
        .alert(String(localized: "error.title"), isPresented: $viewModel.showError) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .confirmationDialog(
            String(localized: "config.deleteConfirmation"),
            isPresented: $viewModel.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                viewModel.deleteSelectedConfigs()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Config List

    private var configList: some View {
        List(selection: Binding(
            get: { viewModel.selectedIndices },
            set: { newSelection in
                viewModel.selectedIndices = newSelection
                if let first = newSelection.sorted().first {
                    appState.selectedConfigIndex = first
                } else {
                    appState.selectedConfigIndex = nil
                }
            }
        )) {
            ForEach(Array(appState.configs.enumerated()), id: \.offset) { index, config in
                configRow(config: config, index: index)
                    .tag(index)
                    .contextMenu { configContextMenu(config: config, index: index) }
            }
            .onMove { source, destination in
                appState.configs.move(fromOffsets: source, toOffset: destination)
                appState.appConfig.sort = appState.configs.map { $0.name }
                appState.saveAppConfig()
            }
        }
        .listStyle(.sidebar)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleFileDrop(providers)
            return true
        }
    }

    private func configRow(config: ClientConfig, index: Int) -> some View {
        HStack(spacing: 8) {
            configStateIcon(for: config.name)
            VStack(alignment: .leading, spacing: 2) {
                Text(config.name)
                    .font(.body)
                    .lineLimit(1)
                Text(serverAddress(for: config))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if config.manualStart {
                Image(systemName: "hand.raised.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .help(String(localized: "config.manualStart"))
            }
        }
        .padding(.vertical, 2)
    }

    private func configStateIcon(for configName: String) -> some View {
        let state = statusTracker.configStates[configName] ?? .unknown
        let (color, icon): (Color, String) = {
            switch state {
            case .started: return (.green, "circle.fill")
            case .stopped: return (.gray, "circle.fill")
            case .starting: return (.orange, "circle.dotted")
            case .stopping: return (.orange, "circle.dotted")
            case .unknown: return (.blue, "circle.fill")
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundColor(color)
    }

    private func serverAddress(for config: ClientConfig) -> String {
        if config.serverAddr.isEmpty {
            return "\(String(localized: "config.noServer"))"
        }
        return "\(config.serverAddr):\(config.serverPort)"
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func configContextMenu(config: ClientConfig, index: Int) -> some View {
        Button {
            viewModel.editingConfig = config
            viewModel.isShowingNewConfigDialog = true
        } label: {
            Label(String(localized: "config.edit"), systemImage: "pencil")
        }

        Divider()

        Menu(String(localized: "config.moveTo")) {
            Button(String(localized: "config.move.top")) {
                viewModel.moveConfig(from: index, direction: .top)
            }
            Button(String(localized: "config.move.up")) {
                viewModel.moveConfig(from: index, direction: .up)
            }
            Button(String(localized: "config.move.down")) {
                viewModel.moveConfig(from: index, direction: .down)
            }
            Button(String(localized: "config.move.bottom")) {
                viewModel.moveConfig(from: index, direction: .bottom)
            }
        }

        Menu(String(localized: "config.duplicate")) {
            Button(String(localized: "config.duplicate.full")) {
                viewModel.duplicateConfig(config, fullCopy: true)
            }
            Button(String(localized: "config.duplicate.basic")) {
                viewModel.duplicateConfig(config, fullCopy: false)
            }
        }

        Divider()

        Button {
            viewModel.importFromClipboard()
        } label: {
            Label(String(localized: "config.importClipboard"), systemImage: "doc.on.clipboard")
        }

        Button {
            viewModel.isShowingNATDialog = true
        } label: {
            Label(String(localized: "config.natCheck"), systemImage: "network.badge.shield.half.filled")
        }

        Button {
            let link = viewModel.generateShareLink(for: config)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link, forType: .string)
        } label: {
            Label(String(localized: "config.shareLink"), systemImage: "square.and.arrow.up")
        }

        Button {
            viewModel.isShowingPropertiesDialog = true
        } label: {
            Label(String(localized: "config.properties"), systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.selectedIndices = [index]
            viewModel.isShowingDeleteConfirmation = true
        } label: {
            Label(String(localized: "common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Bottom Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            Menu {
                Button {
                    viewModel.createNewConfig()
                } label: {
                    Label(String(localized: "config.new.empty"), systemImage: "doc")
                }

                Divider()

                Button {
                    viewModel.isShowingImportFileDialog = true
                } label: {
                    Label(String(localized: "config.import.file"), systemImage: "doc.badge.plus")
                }

                Button {
                    viewModel.importFromClipboard()
                } label: {
                    Label(String(localized: "config.import.clipboard"), systemImage: "doc.on.clipboard")
                }

                Button {
                    viewModel.isShowingImportURLDialog = true
                } label: {
                    Label(String(localized: "config.import.url"), systemImage: "link.badge.plus")
                }
            } label: {
                Image(systemName: "plus")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            Button {
                guard !viewModel.selectedIndices.isEmpty else { return }
                viewModel.isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedIndices.isEmpty)

            Spacer()

            Button {
                viewModel.exportAll()
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "config.exportAll"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - File Drop

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                DispatchQueue.main.async {
                    do {
                        let configs = try ImportExportManager.shared.importFromFiles(urls: [url])
                        for config in configs {
                            viewModel.saveConfig(config)
                        }
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder for config edit dialog

private struct ConfigEditPlaceholder: View {
    let config: ClientConfig
    let onSave: (ClientConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedConfig: ClientConfig

    init(config: ClientConfig, onSave: @escaping (ClientConfig) -> Void) {
        self.config = config
        self.onSave = onSave
        _editedConfig = State(initialValue: config)
    }

    var body: some View {
        VStack {
            Text(String(localized: "config.edit"))
                .font(.headline)
                .padding()

            TextField(String(localized: "config.name"), text: $editedConfig.name)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)

            HStack {
                Button(String(localized: "common.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "common.save")) {
                    onSave(editedConfig)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 200)
    }
}
