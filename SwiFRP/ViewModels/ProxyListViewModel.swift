import SwiftUI
import Combine

class ProxyListViewModel: ObservableObject {
    @Published var selectedProxyIDs: Set<String> = []
    @Published var isShowingEditProxy = false
    @Published var isShowingQuickAdd = false
    @Published var editingProxy: ProxyConfig? = nil
    @Published var showRemoteAddress = false

    var config: ClientConfig

    init(config: ClientConfig) {
        self.config = config
    }

    // MARK: - Proxy CRUD

    func addProxy(_ proxy: ProxyConfig) {
        config.proxies.append(proxy)
        editingProxy = nil
    }

    func editProxy(_ proxy: ProxyConfig) {
        editingProxy = proxy
        isShowingEditProxy = true
    }

    func saveProxy(_ proxy: ProxyConfig) {
        if let index = config.proxies.firstIndex(where: { $0.name == proxy.name }) {
            config.proxies[index] = proxy
        } else {
            config.proxies.append(proxy)
        }
        editingProxy = nil
        isShowingEditProxy = false
    }

    func deleteSelectedProxies() {
        let indicesToRemove = selectedProxyIDs.compactMap { id in
            config.proxies.firstIndex(where: { $0.id == id })
        }.sorted(by: >)
        for index in indicesToRemove {
            guard index >= 0, index < config.proxies.count else { continue }
            config.proxies.remove(at: index)
        }
        selectedProxyIDs.removeAll()
    }

    func toggleProxyEnabled(at index: Int) {
        guard index >= 0, index < config.proxies.count else { return }
        config.proxies[index].disabled.toggle()
    }

    func moveProxy(from source: Int, direction: MoveDirection) {
        let target: Int
        switch direction {
        case .up: target = max(0, source - 1)
        case .down: target = min(config.proxies.count - 1, source + 1)
        case .top: target = 0
        case .bottom: target = config.proxies.count - 1
        }
        guard target != source else { return }
        config.proxies.move(fromOffsets: IndexSet(integer: source), toOffset: target > source ? target + 1 : target)
    }

    // MARK: - Import

    func importFromClipboard() {
        #if canImport(AppKit)
        guard let content = NSPasteboard.general.string(forType: .string) else { return }
        let converter = ConfigConverter()
        let format = converter.detectFormat(content)
        let tempName = "clipboard_import"
        let parsed: ClientConfig
        if format == .ini {
            parsed = converter.iniToConfig(content, name: tempName)
        } else {
            parsed = converter.tomlToConfig(content, name: tempName)
        }
        for proxy in parsed.proxies {
            config.proxies.append(proxy)
        }
        #endif
    }

    // MARK: - Access Address

    func copyAccessAddress(for proxy: ProxyConfig, serverAddr: String) -> String {
        let addr = serverAddr.isEmpty ? "server_addr" : serverAddr

        switch proxy.type {
        case "http", "https":
            if !proxy.customDomains.isEmpty {
                return "\(proxy.type)://\(proxy.customDomains[0])"
            }
            if !proxy.subdomain.isEmpty {
                return "\(proxy.type)://\(proxy.subdomain).\(addr)"
            }
            return "\(proxy.type)://\(addr)"
        case "tcp", "udp":
            let port = proxy.remotePort.map(String.init) ?? "remote_port"
            return "\(addr):\(port)"
        case "stcp", "xtcp", "sudp":
            return "\(proxy.type)://\(proxy.name)"
        case "tcpmux":
            if !proxy.customDomains.isEmpty {
                return "\(proxy.customDomains[0])"
            }
            return addr
        default:
            return "\(addr):\(proxy.remotePort.map(String.init) ?? "")"
        }
    }

    // MARK: - Quick Add Templates

    func addOpenPort(name: String = "", localPort: Int, remotePort: Int) {
        var proxy = ProxyConfig(name: name.isEmpty ? "open_port_\(localPort)" : name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = localPort
        proxy.remotePort = remotePort
        addProxy(proxy)
    }

    func addRemoteDesktop(name: String = "remote_desktop") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 3389
        proxy.remotePort = 3389
        addProxy(proxy)
    }

    func addVNC(name: String = "vnc") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 5900
        proxy.remotePort = 5900
        addProxy(proxy)
    }

    func addSSH(name: String = "ssh") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 22
        proxy.remotePort = 6000
        addProxy(proxy)
    }

    func addWeb(name: String = "web", localPort: Int = 80) {
        var proxy = ProxyConfig(name: name)
        proxy.type = "http"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = localPort
        addProxy(proxy)
    }

    func addFTP(name: String = "ftp") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 21
        proxy.remotePort = 6021
        addProxy(proxy)
    }

    func addHTTPFileServer(name: String = "http_file_server", localPath: String = "") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 8080
        proxy.remotePort = 8080
        proxy.plugin.name = "static_file"
        proxy.plugin.localPath = localPath
        addProxy(proxy)
    }

    func addProxyServer(name: String = "socks5_proxy") {
        var proxy = ProxyConfig(name: name)
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 1080
        proxy.remotePort = 1080
        proxy.plugin.name = "socks5"
        addProxy(proxy)
    }
}
