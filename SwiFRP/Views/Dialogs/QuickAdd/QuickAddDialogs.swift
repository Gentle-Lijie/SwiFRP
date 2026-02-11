import SwiftUI

// MARK: - Open Port Dialog

struct OpenPortDialog: View {
    @Binding var isPresented: Bool
    var onAdd: (ProxyConfig) -> Void

    @State private var portNumber: String = ""
    @State private var protocolChoice: String = "tcp"

    private let protocolOptions = ["tcp", "udp", "both"]

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "quickAdd.openPort.title"))
                .font(.headline)

            Form {
                TextField(String(localized: "quickAdd.openPort.port"), text: $portNumber)

                Picker(String(localized: "quickAdd.openPort.protocol"), selection: $protocolChoice) {
                    ForEach(protocolOptions, id: \.self) { opt in
                        Text(opt.uppercased()).tag(opt)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.cancel")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "common.add")) { addProxy() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(portNumber.isEmpty)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func addProxy() {
        let port = portNumber.trimmingCharacters(in: .whitespaces)
        guard let portInt = Int(port), portInt > 0 else { return }

        if protocolChoice == "both" {
            var tcpProxy = ProxyConfig(name: "open_tcp_\(port)")
            tcpProxy.type = "tcp"
            tcpProxy.localIP = "127.0.0.1"
            tcpProxy.localPort = portInt
            tcpProxy.remotePort = portInt
            onAdd(tcpProxy)

            var udpProxy = ProxyConfig(name: "open_udp_\(port)")
            udpProxy.type = "udp"
            udpProxy.localIP = "127.0.0.1"
            udpProxy.localPort = portInt
            udpProxy.remotePort = portInt
            onAdd(udpProxy)
        } else {
            var proxy = ProxyConfig(name: "open_\(protocolChoice)_\(port)")
            proxy.type = protocolChoice
            proxy.localIP = "127.0.0.1"
            proxy.localPort = portInt
            proxy.remotePort = portInt
            onAdd(proxy)
        }

        isPresented = false
    }
}

// MARK: - Simple Proxy Dialog

struct SimpleProxyDialog: View {
    @Binding var isPresented: Bool
    var onAdd: (ProxyConfig) -> Void

    private let presets: [(name: String, port: Int, type: String)] = [
        ("rdp", 3389, "tcp"),
        ("vnc", 5900, "tcp"),
        ("ssh", 22, "tcp"),
        ("web", 80, "http"),
        ("ftp", 21, "tcp"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "quickAdd.simpleProxy.title"))
                .font(.headline)

            List {
                ForEach(presets, id: \.name) { preset in
                    Button {
                        addPreset(preset)
                    } label: {
                        HStack {
                            Text(preset.name.uppercased())
                                .fontWeight(.medium)
                            Spacer()
                            Text(String(localized: "quickAdd.simpleProxy.port") + " \(preset.port)")
                                .foregroundColor(.secondary)
                            Text("(\(preset.type))")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 150)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.close")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func addPreset(_ preset: (name: String, port: Int, type: String)) {
        var proxy = ProxyConfig(name: preset.name)
        proxy.type = preset.type
        proxy.localIP = "127.0.0.1"
        proxy.localPort = preset.port
        if proxy.type != "http" {
            proxy.remotePort = preset.port
        }
        onAdd(proxy)
        isPresented = false
    }
}

// MARK: - HTTP File Server Dialog

struct HTTPFileServerDialog: View {
    @Binding var isPresented: Bool
    var onAdd: (ProxyConfig) -> Void

    @State private var localPath: String = ""
    @State private var stripPrefix: String = ""
    @State private var httpUser: String = ""
    @State private var httpPwd: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "quickAdd.httpFileServer.title"))
                .font(.headline)

            Form {
                BrowseField(
                    label: String(localized: "quickAdd.httpFileServer.localPath"),
                    path: $localPath,
                    canChooseDirectories: true
                )
                TextField(String(localized: "quickAdd.httpFileServer.stripPrefix"), text: $stripPrefix)

                Section(String(localized: "quickAdd.httpFileServer.auth")) {
                    TextField(String(localized: "quickAdd.httpFileServer.user"), text: $httpUser)
                    SecureField(String(localized: "quickAdd.httpFileServer.password"), text: $httpPwd)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.cancel")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "common.add")) { addProxy() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(localPath.isEmpty)
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func addProxy() {
        var proxy = ProxyConfig(name: "http_file_server")
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.localPort = 8080
        proxy.remotePort = 8080
        proxy.plugin.name = "static_file"
        proxy.plugin.localPath = localPath
        proxy.plugin.stripPrefix = stripPrefix
        proxy.plugin.staticFileUser = httpUser
        proxy.plugin.staticFilePwd = httpPwd
        onAdd(proxy)
        isPresented = false
    }
}

// MARK: - Proxy Server Dialog

struct ProxyServerDialog: View {
    @Binding var isPresented: Bool
    var onAdd: (ProxyConfig) -> Void

    @State private var proxyType: String = "socks5"
    @State private var userName: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 12) {
            Text(String(localized: "quickAdd.proxyServer.title"))
                .font(.headline)

            Form {
                Picker(String(localized: "quickAdd.proxyServer.type"), selection: $proxyType) {
                    Text("SOCKS5").tag("socks5")
                    Text("HTTP Proxy").tag("http_proxy")
                }

                TextField(String(localized: "quickAdd.proxyServer.user"), text: $userName)
                SecureField(String(localized: "quickAdd.proxyServer.password"), text: $password)
            }

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.cancel")) { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Button(String(localized: "common.add")) { addProxy() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 380)
    }

    private func addProxy() {
        var proxy = ProxyConfig(name: "\(proxyType)_proxy")
        proxy.type = "tcp"
        proxy.localIP = "127.0.0.1"
        proxy.plugin.name = proxyType

        if proxyType == "socks5" {
            proxy.localPort = 1080
            proxy.remotePort = 1080
            proxy.plugin.socks5User = userName
            proxy.plugin.socks5Pwd = password
        } else {
            proxy.localPort = 8080
            proxy.remotePort = 8080
            proxy.plugin.httpUser = userName
            proxy.plugin.httpPwd = password
        }

        onAdd(proxy)
        isPresented = false
    }
}
