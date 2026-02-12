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
            proxyList
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
            L("proxy.deleteConfirmation"),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("common.delete"), role: .destructive) {
                viewModel.deleteSelectedProxies()
                syncProxiesToConfig()
            }
            Button(L("common.cancel"), role: .cancel) {}
        }
    }

    // MARK: - Proxy List

    private var proxyList: some View {
        List(selection: $viewModel.selectedProxyIDs) {
            ForEach(Array(config.proxies.enumerated()), id: \.element.id) { index, proxy in
                HStack(spacing: 8) {
                    proxyStateIcon(for: proxy)
                        .frame(width: 12)
                    
                    Text(proxy.name)
                        .strikethrough(proxy.disabled)
                        .foregroundColor(proxy.disabled ? .secondary : .primary)
                        .frame(width: 100, alignment: .leading)
                    
                    Text(proxy.type)
                        .foregroundColor(proxyTypeColor(proxy.type))
                        .frame(width: 60)
                    
                    Text(proxy.localIP)
                        .font(.caption)
                        .frame(width: 100)
                    
                    Text(proxy.localPort.map(String.init) ?? "-")
                        .font(.caption)
                        .frame(width: 60)
                    
                    Text(proxy.remotePort.map(String.init) ?? "-")
                        .font(.caption)
                        .frame(width: 60)
                    
                    Text(domainDisplay(for: proxy))
                        .font(.caption)
                        .lineLimit(1)
                        .frame(width: 120, alignment: .leading)
                    
                    Text(proxy.plugin.name.isEmpty ? "-" : proxy.plugin.name)
                        .font(.caption)
                        .foregroundColor(proxy.plugin.name.isEmpty ? .secondary : .primary)
                        .frame(width: 80)
                    
                    if viewModel.showRemoteAddress {
                        let status = proxyStatuses.first { $0.name == proxy.name }
                        Text(status?.remoteAddr ?? "-")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 100)
                    }
                }
                .tag(proxy.id)
                .contextMenu { proxyContextMenu(proxy: proxy, index: index) }
            }
        }
        .listStyle(.inset)
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
            .help(L("proxy.add"))

            quickAddMenu

            Button {
                guard let selectedID = viewModel.selectedProxyIDs.first,
                      let index = config.proxies.firstIndex(where: { $0.id == selectedID }) else { return }
                viewModel.editProxy(config.proxies[index])
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIDs.count != 1)
            .help(L("proxy.edit"))

            Button {
                for id in viewModel.selectedProxyIDs {
                    guard let index = config.proxies.firstIndex(where: { $0.id == id }) else { continue }
                    viewModel.toggleProxyEnabled(at: index)
                }
                syncProxiesToConfig()
                saveAndReloadConfig()
            } label: {
                Image(systemName: "eye.slash")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIDs.isEmpty)
            .help(L("proxy.toggleEnabled"))

            Divider()
                .frame(height: 16)

            Button {
                guard let selectedID = viewModel.selectedProxyIDs.first,
                      let index = config.proxies.firstIndex(where: { $0.id == selectedID }) else { return }
                viewModel.moveProxy(from: index, direction: .up)
                syncProxiesToConfig()
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIDs.count != 1)

            Button {
                guard let selectedID = viewModel.selectedProxyIDs.first,
                      let index = config.proxies.firstIndex(where: { $0.id == selectedID }) else { return }
                viewModel.moveProxy(from: index, direction: .down)
                syncProxiesToConfig()
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIDs.count != 1)

            Spacer()

            Button {
                guard !viewModel.selectedProxyIDs.isEmpty else { return }
                isShowingDeleteConfirmation = true
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedProxyIDs.isEmpty)
            .help(L("proxy.delete"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Quick Add Menu

    private var quickAddMenu: some View {
        Menu {
            Button(L("proxy.quick.ssh")) {
                viewModel.addSSH()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.web")) {
                viewModel.addWeb()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.remoteDesktop")) {
                viewModel.addRemoteDesktop()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.vnc")) {
                viewModel.addVNC()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.ftp")) {
                viewModel.addFTP()
                syncProxiesToConfig()
            }
            Divider()
            Button(L("proxy.quick.httpFileServer")) {
                viewModel.addHTTPFileServer()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.socks5Proxy")) {
                viewModel.addProxyServer()
                syncProxiesToConfig()
            }
        } label: {
            Image(systemName: "bolt.fill")
        }
        .menuStyle(.borderlessButton)
        .frame(width: 28)
        .help(L("proxy.quickAdd"))
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func proxyContextMenu(proxy: ProxyConfig, index: Int) -> some View {
        Button {
            viewModel.editProxy(proxy)
        } label: {
            Label(L("proxy.edit"), systemImage: "pencil")
        }

        Button {
            viewModel.toggleProxyEnabled(at: index)
            syncProxiesToConfig()
            saveAndReloadConfig()
        } label: {
            Label(
                proxy.disabled
                    ? L("proxy.enable")
                    : L("proxy.disable"),
                systemImage: proxy.disabled ? "eye" : "eye.slash"
            )
        }

        Divider()

        Menu(L("proxy.moveTo")) {
            Button(L("config.move.top")) {
                viewModel.moveProxy(from: index, direction: .top)
                syncProxiesToConfig()
            }
            Button(L("config.move.up")) {
                viewModel.moveProxy(from: index, direction: .up)
                syncProxiesToConfig()
            }
            Button(L("config.move.down")) {
                viewModel.moveProxy(from: index, direction: .down)
                syncProxiesToConfig()
            }
            Button(L("config.move.bottom")) {
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
            Label(L("proxy.new"), systemImage: "plus")
        }

        Menu(L("proxy.quickAdd")) {
            Button(L("proxy.quick.ssh")) {
                viewModel.addSSH()
                syncProxiesToConfig()
            }
            Button(L("proxy.quick.web")) {
                viewModel.addWeb()
                syncProxiesToConfig()
            }
        }

        Button {
            viewModel.importFromClipboard()
            syncProxiesToConfig()
        } label: {
            Label(L("proxy.importClipboard"), systemImage: "doc.on.clipboard")
        }

        Divider()

        Toggle(L("proxy.showRemoteAddr"), isOn: $viewModel.showRemoteAddress)

        Button {
            let addr = viewModel.copyAccessAddress(for: proxy, serverAddr: config.serverAddr)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(addr, forType: .string)
        } label: {
            Label(L("proxy.copyAccessAddr"), systemImage: "doc.on.doc")
        }

        Button {
            viewModel.selectedProxyIDs = Set(config.proxies.map { $0.id })
        } label: {
            Label(L("common.selectAll"), systemImage: "checkmark.circle")
        }

        Divider()

        Button(role: .destructive) {
            viewModel.selectedProxyIDs = [proxy.id]
            isShowingDeleteConfirmation = true
        } label: {
            Label(L("common.delete"), systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func proxyStateIcon(for proxy: ProxyConfig) -> some View {
        let status = proxyStatuses.first { $0.name == proxy.name }
        let configState = statusTracker.configStates[config.name] ?? .unknown
        
        // Determine icon appearance based on state
        let (iconName, color, tooltip): (String, Color, String) = {
            // If proxy is disabled
            if proxy.disabled {
                return ("pause.circle.fill", .gray, L("proxy.status.disabled"))
            }
            
            // If config service is not running
            if configState != .started {
                return ("circle.dashed", .secondary, L("proxy.status.serviceStopped"))
            }
            
            // If service is running and we have admin API status
            if config.adminPort > 0, let status = status {
                switch status.status {
                case .running:
                    return ("checkmark.circle.fill", .green, L("proxy.status.running"))
                case .error:
                    return ("xmark.circle.fill", .red, "\(L("proxy.status.error")): \(status.error)")
                case .unknown:
                    return ("questionmark.circle", .secondary, L("proxy.status.unknown"))
                }
            }
            
            // If service is running but no admin API configured
            // Try to fetch status from admin API, but don't assume success
            if config.adminPort == 0 {
                return ("checkmark.circle", .secondary, "\(L("proxy.status.running")) (\(L("proxy.status.hint.adminAPI")))")
            }
            
            // Service running, admin API configured but no status yet
            return ("circle", .secondary, L("proxy.status.checking"))
        }()
        
        return Image(systemName: iconName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(color)
            .help(tooltip)
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
        // Save to file immediately
        ConfigFileManager.shared.saveConfig(config)
    }
    private func saveAndReloadConfig() {
        // Save config to file
        ConfigFileManager.shared.saveConfig(config)
        
        // Hot reload if service is running
        let state = statusTracker.configStates[config.name] ?? .unknown
        if state == .started && config.adminPort > 0 {
            Task {
                do {
                    try await FRPCBridge.shared.reload(
                        adminAddr: config.adminAddr.isEmpty ? "127.0.0.1" : config.adminAddr,
                        adminPort: config.adminPort,
                        user: config.adminUser.isEmpty ? nil : config.adminUser,
                        password: config.adminPwd.isEmpty ? nil : config.adminPwd
                    )
                    // Refresh proxy statuses after reload
                    await statusTracker.probeProxies(for: config)
                } catch {
                    print("Failed to hot reload config: \(error)")
                }
            }
        }
    }
}

// MARK: - Placeholder for proxy edit dialog

private struct ProxyEditPlaceholder: View {
    let proxy: ProxyConfig
    let onSave: (ProxyConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editedProxy: ProxyConfig
    @State private var isPresented = true

    init(proxy: ProxyConfig, onSave: @escaping (ProxyConfig) -> Void) {
        self.proxy = proxy
        self.onSave = onSave
        _editedProxy = State(initialValue: proxy)
    }

    var body: some View {
        EditProxyDialog(
            proxy: $editedProxy,
            isPresented: $isPresented
        ) { saved in
            onSave(saved)
        }
        .onDisappear {
            // Ensure dismissal is handled
        }
    }
}
