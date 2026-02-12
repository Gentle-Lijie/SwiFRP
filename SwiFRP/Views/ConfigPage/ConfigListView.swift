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
                EditClientDialog(
                    config: Binding(
                        get: { config },
                        set: { _ in }
                    ),
                    isPresented: $viewModel.isShowingNewConfigDialog
                ) { saved in
                    viewModel.saveConfig(saved)
                }
            }
        }
        .alert(L("error.title"), isPresented: $viewModel.showError) {
            Button(L("common.ok"), role: .cancel) {}
        } message: {
            if let msg = viewModel.errorMessage {
                Text(msg)
            }
        }
        .confirmationDialog(
            L("config.deleteConfirmation"),
            isPresented: $viewModel.isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.delete"), role: .destructive) {
                viewModel.deleteSelectedConfigs()
            }
            Button(L("common.cancel"), role: .cancel) {}
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
                    .help(L("config.manualStart"))
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
            return "\(L("config.noServer"))"
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
            Label(L("config.edit"), systemImage: "pencil")
        }

        Divider()

        Menu(L("config.moveTo")) {
            Button(L("config.move.top")) {
                viewModel.moveConfig(from: index, direction: .top)
            }
            Button(L("config.move.up")) {
                viewModel.moveConfig(from: index, direction: .up)
            }
            Button(L("config.move.down")) {
                viewModel.moveConfig(from: index, direction: .down)
            }
            Button(L("config.move.bottom")) {
                viewModel.moveConfig(from: index, direction: .bottom)
            }
        }

        Menu(L("config.duplicate")) {
            Button(L("config.duplicate.full")) {
                viewModel.duplicateConfig(config, fullCopy: true)
            }
            Button(L("config.duplicate.basic")) {
                viewModel.duplicateConfig(config, fullCopy: false)
            }
        }

        Divider()

        Button {
            viewModel.importFromClipboard()
        } label: {
            Label(L("config.importClipboard"), systemImage: "doc.on.clipboard")
        }

        Button {
            viewModel.isShowingNATDialog = true
        } label: {
            Label(L("config.natCheck"), systemImage: "network.badge.shield.half.filled")
        }

        Button {
            let link = viewModel.generateShareLink(for: config)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(link, forType: .string)
        } label: {
            Label(L("config.shareLink"), systemImage: "square.and.arrow.up")
        }

        Button {
            viewModel.isShowingPropertiesDialog = true
        } label: {
            Label(L("config.properties"), systemImage: "info.circle")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.selectedIndices = [index]
            viewModel.isShowingDeleteConfirmation = true
        } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Bottom Toolbar

    private var toolbar: some View {
        HStack(spacing: 4) {
            Menu {
                Button {
                    viewModel.createNewConfig()
                } label: {
                    Label(L("config.new.empty"), systemImage: "doc")
                }

                Divider()

                Button {
                    viewModel.isShowingImportFileDialog = true
                } label: {
                    Label(L("config.import.file"), systemImage: "doc.badge.plus")
                }

                Button {
                    viewModel.importFromClipboard()
                } label: {
                    Label(L("config.import.clipboard"), systemImage: "doc.on.clipboard")
                }

                Button {
                    viewModel.isShowingImportURLDialog = true
                } label: {
                    Label(L("config.import.url"), systemImage: "link.badge.plus")
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
            .help(L("config.exportAll"))
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
