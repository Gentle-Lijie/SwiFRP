import SwiftUI

struct LogPageView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = LogViewModel()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            logContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if viewModel.selectedConfigName == nil, let first = appState.configs.first {
                viewModel.selectConfig(first.name)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Picker(String(localized: "log.config"), selection: Binding(
                get: { viewModel.selectedConfigName ?? "" },
                set: { viewModel.selectConfig($0.isEmpty ? nil : $0) }
            )) {
                Text(String(localized: "log.selectConfig")).tag("")
                ForEach(appState.configs, id: \.name) { config in
                    Text(config.name).tag(config.name)
                }
            }
            .frame(width: 200)

            if !viewModel.availableLogFiles.isEmpty {
                Picker(String(localized: "log.logFile"), selection: Binding(
                    get: { viewModel.selectedLogFile?.absoluteString ?? "" },
                    set: { urlString in
                        let url = viewModel.availableLogFiles.first { $0.absoluteString == urlString }
                        viewModel.selectLogFile(url)
                    }
                )) {
                    ForEach(viewModel.availableLogFiles, id: \.absoluteString) { url in
                        Text(url.lastPathComponent).tag(url.absoluteString)
                    }
                }
                .frame(width: 200)
            }

            Spacer()

            Toggle(String(localized: "log.autoRefresh"), isOn: Binding(
                get: { viewModel.isAutoRefreshing },
                set: { $0 ? viewModel.startAutoRefresh() : viewModel.stopAutoRefresh() }
            ))
            .toggleStyle(.switch)

            Button {
                viewModel.openLogFolder()
            } label: {
                Label(String(localized: "log.openFolder"), systemImage: "folder")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Log Content

    private var logContent: some View {
        Group {
            if viewModel.logContent.isEmpty {
                VStack {
                    Spacer()
                    Text(String(localized: "log.noContent"))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                ScrollViewReader { scrollProxy in
                    ScrollView([.horizontal, .vertical]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(viewModel.logContent.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: viewModel.logContent.count) { _ in
                        if let lastIndex = viewModel.logContent.indices.last {
                            withAnimation {
                                scrollProxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
