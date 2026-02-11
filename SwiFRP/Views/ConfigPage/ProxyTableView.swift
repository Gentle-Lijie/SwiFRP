import SwiftUI

struct ProxyTableView: View {
    @Binding var config: ClientConfig
    @ObservedObject var viewModel: ProxyListViewModel
    @ObservedObject private var statusTracker = StatusTracker.shared
    @State private var isShowingDeleteConfirmation = false

    private var proxyStatuses: [ProxyStatus] {
        statusTracker.proxyStatuses[config.name] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            proxyTable
            Divider()
            proxyToolbar
        }
        .sheet(isPresented: $viewModel.isShowingEditProxy) {
            if let proxy = viewModel.editingProxy {
                ProxyEditPlaceholder(proxy: proxy) { saved in
                    viewModel.saveProxy(saved)
                    syncProxiesToConfig()
                }
            }
        }
        .confirmationDialog(
            String(localized: "proxy.deleteConfirmation"),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "common.delete"), role: .destructive) {
                viewModel.deleteSelectedProxies()
                syncProxiesToConfig()
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Proxy Table

    private var proxyTable: some View {
        Table(of: IndexedProxy.self, selection: Binding(
            get: { viewModel.selectedProxyIndices },
            set: { viewModel.selectedProxyIndices = $0 }
        )) {
            TableColumn(String(localized: "proxy.column.name")) { item in
                HStack(spacing: 6) {
                    proxyStateIcon(for: item.proxy)
                    Text(item.proxy.name)
                        .strikethrough(item.proxy.disabled)
                        .foregroundColor(item.proxy.disabled ? .secondary : .primary)
                }
            }
            .width(min: 80, ideal: 120)

            TableColumn(String(localized: "proxy.column.type")) { item in
                Text(item.proxy.type)
                    .foregroundColor(proxyTypeColor(item.proxy.type))
            }
            .width(min: 50, ideal: 60)

            TableColumn(String(localized: "proxy.column.localAddr")) { item in
                Text(item.proxy.localIP)
                    .font(.caption)
            }
            .width(min: 80, ideal: 100)

            TableColumn(String(localized: "proxy.column.localPort")) { item in
                Text(item.proxy.localPort.map(String.init) ?? "")
                    .font(.caption)
            }
            .width(min: 60, ideal: 70)

            TableColumn(String(localized: "proxy.column.remotePort")) { item in
                Text(item.proxy.remotePort.map(String.init) ?? "")
                    .font(.caption)
            }
            .width(min: 60, ideal: 80)

            TableColumn(String(localized: "proxy.column.domain")) { item in
                Text(domainDisplay(for: item.proxy))
                    .font(.caption)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 120)

            TableColumn(String(localized: "proxy.column.plugin")) { item in
                Text(item.proxy.plugin.name.isEmpty ? "-" : item.proxy.plugin.name)
                    .font(.caption)
                    .foregroundColor(item.proxy.plugin.name.isEmpty ? .secondary : .primary)
            }
            .width(min: 60, ideal: 80)

            if viewModel.showRemoteAddress {
                TableColumn(String(localized: "proxy.column.remoteAddr")) { item in
                    let status = proxyStatuses.first { $0.name == item.proxy.name }
                    Text(status?.remoteAddr ?? "-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .width(min: 80, ideal: 120)
            }
        } rows: {
            ForEach(indexedProxies) { item in
                TableRow(item)
                    .contextMenu { proxyContextMenu(proxy: item.proxy, index: item.index) }
            }
        }
    }

    // MARK: - Proxy Toolbar

    private var proxyToolbar: some View {
        HStack(spacing: 4) {
            Button {
                var newProxy = ProxyConfig(name: "proxy_\(config.proxies.count + 1)")
                newProxy.type = "tcp"
                viewModel.editingProxy = newProxy
                viewModel.isShowingEditProxy = true
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help(String(localized: "proxy.add"))

            quickAddMenu

            Button {
                guard let firstIndex = viewModel.selectedProxyIndices.sorted().first,
                      firstIndex >= 0, firstIndex < config.proxies.count else { return }
                viewModel.editProxy(config.proxies[firstIndex])
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIndices.count != 1)
            .help(String(localized: "proxy.edit"))

            Button {
                for index in viewModel.selectedProxyIndices {
                    viewModel.toggleProxyEnabled(at: index)
                }
                syncProxiesToConfig()
            } label: {
                Image(systemName: "eye.slash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIndices.isEmpty)
            .help(String(localized: "proxy.toggleEnabled"))

            Divider()
                .frame(height: 16)

            Button {
                guard let index = viewModel.selectedProxyIndices.sorted().first else { return }
                viewModel.moveProxy(from: index, direction: .up)
                syncProxiesToConfig()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIndices.count != 1)

            Button {
                guard let index = viewModel.selectedProxyIndices.sorted().first else { return }
                viewModel.moveProxy(from: index, direction: .down)
                syncProxiesToConfig()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIndices.count != 1)

            Spacer()

            Button {
                guard !viewModel.selectedProxyIndices.isEmpty else { return }
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIndices.isEmpty)
            .help(String(localized: "proxy.delete"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Quick Add Menu

    private var quickAddMenu: some View {
        Menu {
            Button(String(localized: "proxy.quick.ssh")) {
                viewModel.addSSH()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.web")) {
                viewModel.addWeb()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.remoteDesktop")) {
                viewModel.addRemoteDesktop()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.vnc")) {
                viewModel.addVNC()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.ftp")) {
                viewModel.addFTP()
                syncProxiesToConfig()
            }
            Divider()
            Button(String(localized: "proxy.quick.httpFileServer")) {
                viewModel.addHTTPFileServer()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.socks5Proxy")) {
                viewModel.addProxyServer()
                syncProxiesToConfig()
            }
        } label: {
            Image(systemName: "bolt.fill")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
        .help(String(localized: "proxy.quickAdd"))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func proxyContextMenu(proxy: ProxyConfig, index: Int) -> some View {
        Button {
            viewModel.editProxy(proxy)
        } label: {
            Label(String(localized: "proxy.edit"), systemImage: "pencil")
        }

        Button {
            viewModel.toggleProxyEnabled(at: index)
            syncProxiesToConfig()
        } label: {
            Label(
                proxy.disabled
                    ? String(localized: "proxy.enable")
                    : String(localized: "proxy.disable"),
                systemImage: proxy.disabled ? "eye" : "eye.slash"
            )
        }

        Divider()

        Menu(String(localized: "proxy.moveTo")) {
            Button(String(localized: "config.move.top")) {
                viewModel.moveProxy(from: index, direction: .top)
                syncProxiesToConfig()
            }
            Button(String(localized: "config.move.up")) {
                viewModel.moveProxy(from: index, direction: .up)
                syncProxiesToConfig()
            }
            Button(String(localized: "config.move.down")) {
                viewModel.moveProxy(from: index, direction: .down)
                syncProxiesToConfig()
            }
            Button(String(localized: "config.move.bottom")) {
                viewModel.moveProxy(from: index, direction: .bottom)
                syncProxiesToConfig()
            }
        }

        Divider()

        Button {
            var newProxy = ProxyConfig(name: "proxy_\(config.proxies.count + 1)")
            newProxy.type = "tcp"
            viewModel.editingProxy = newProxy
            viewModel.isShowingEditProxy = true
        } label: {
            Label(String(localized: "proxy.new"), systemImage: "plus")
        }

        Menu(String(localized: "proxy.quickAdd")) {
            Button(String(localized: "proxy.quick.ssh")) {
                viewModel.addSSH()
                syncProxiesToConfig()
            }
            Button(String(localized: "proxy.quick.web")) {
                viewModel.addWeb()
                syncProxiesToConfig()
            }
        }

        Button {
            viewModel.importFromClipboard()
            syncProxiesToConfig()
        } label: {
            Label(String(localized: "proxy.importClipboard"), systemImage: "doc.on.clipboard")
        }

        Divider()

        Toggle(String(localized: "proxy.showRemoteAddr"), isOn: $viewModel.showRemoteAddress)

        Button {
            let addr = viewModel.copyAccessAddress(for: proxy, serverAddr: config.serverAddr)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(addr, forType: .string)
        } label: {
            Label(String(localized: "proxy.copyAccessAddr"), systemImage: "doc.on.doc")
        }

        Button {
            viewModel.selectedProxyIndices = Set(0..<config.proxies.count)
        } label: {
            Label(String(localized: "common.selectAll"), systemImage: "checkmark.circle")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.selectedProxyIndices = [index]
            isShowingDeleteConfirmation = true
        } label: {
            Label(String(localized: "common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private var indexedProxies: [IndexedProxy] {
        config.proxies.enumerated().map { IndexedProxy(index: $0, proxy: $1) }
    }

    private func proxyStateIcon(for proxy: ProxyConfig) -> some View {
        let status = proxyStatuses.first { $0.name == proxy.name }
        let (color, icon): (Color, String) = {
            if proxy.disabled {
                return (.gray, "circle.dashed")
            }
            guard let status = status else {
                return (.secondary, "circle")
            }
            switch status.status {
            case .running: return (.green, "circle.fill")
            case .error: return (.red, "exclamationmark.circle.fill")
            case .unknown: return (.secondary, "circle")
            }
        }()
        return Image(systemName: icon)
            .font(.system(size: 8))
            .foregroundColor(color)
    }

    private func proxyTypeColor(_ type: String) -> Color {
        switch type {
        case "http", "https": return .blue
        case "tcp": return .primary
        case "udp": return .orange
        case "stcp", "xtcp", "sudp": return .purple
        case "tcpmux": return .teal
        default: return .primary
        }
    }

    private func domainDisplay(for proxy: ProxyConfig) -> String {
        if !proxy.customDomains.isEmpty {
            return proxy.customDomains.joined(separator: ", ")
        }
        if !proxy.subdomain.isEmpty {
            return proxy.subdomain
        }
        return "-"
    }

    private func syncProxiesToConfig() {
        config.proxies = viewModel.config.proxies
    }
}

// MARK: - IndexedProxy

struct IndexedProxy: Identifiable {
    let index: Int
    let proxy: ProxyConfig
    var id: String { "\(index)-\(proxy.name)" }
}

// MARK: - Placeholder for proxy edit dialog

private struct ProxyEditPlaceholder: View {
    let proxy: ProxyConfig
    let onSave: (ProxyConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedProxy: ProxyConfig

    init(proxy: ProxyConfig, onSave: @escaping (ProxyConfig) -> Void) {
        self.proxy = proxy
        self.onSave = onSave
        _editedProxy = State(initialValue: proxy)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "proxy.edit"))
                .font(.headline)
                .padding(.top)

            Form {
                TextField(String(localized: "proxy.column.name"), text: $editedProxy.name)
                Picker(String(localized: "proxy.column.type"), selection: $editedProxy.type) {
                    ForEach(Constants.proxyTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                TextField(String(localized: "proxy.column.localPort"), value: $editedProxy.localPort, format: .number)
                TextField(String(localized: "proxy.column.remotePort"), value: $editedProxy.remotePort, format: .number)
            }
            .padding(.horizontal)

            HStack {
                Button(String(localized: "common.cancel")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "common.save")) {
                    onSave(editedProxy)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom)
        }
        .frame(width: 420, height: 300)
    }
}
