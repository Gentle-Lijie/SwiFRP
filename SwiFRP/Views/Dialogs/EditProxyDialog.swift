import SwiftUI

struct EditProxyDialog: View {
    @Binding var proxy: ProxyConfig
    @Binding var isPresented: Bool
    var isLegacyFormat: Bool = false
    var onSave: (ProxyConfig) -> Void

    @State private var draft: ProxyConfig = ProxyConfig(name: "")
    @State private var selectedTab = 0
    @State private var validationError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            TabView(selection: $selectedTab) {
                basicTab.tag(0).tabItem { Text(String(localized: "proxy.tab.basic")) }
                advancedTab.tag(1).tabItem { Text(String(localized: "proxy.tab.advanced")) }
                pluginTab.tag(2).tabItem { Text(String(localized: "proxy.tab.plugin")) }
                loadBalanceTab.tag(3).tabItem { Text(String(localized: "proxy.tab.loadBalance")) }
                healthCheckTab.tag(4).tabItem { Text(String(localized: "proxy.tab.healthCheck")) }
                metadataTab.tag(5).tabItem { Text(String(localized: "proxy.tab.metadata")) }
            }
            .padding(.horizontal)

            Divider()

            HStack {
                if let error = validationError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                Spacer()
                Button(String(localized: "common.cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "common.save")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 560, minHeight: 500)
        .onAppear { draft = proxy }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            TextField(String(localized: "proxy.name"), text: $draft.name)
                .textFieldStyle(.roundedBorder)

            Button {
                draft.name = StringUtils.generateRandomName()
            } label: {
                Image(systemName: "dice")
            }
            .help(String(localized: "proxy.randomName"))

            Picker(String(localized: "proxy.type"), selection: $draft.type) {
                ForEach(Constants.proxyTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .frame(width: 160)

            if !isLegacyFormat {
                Button {
                    selectedTab = 5
                } label: {
                    Image(systemName: "tag")
                }
                .help(String(localized: "proxy.annotations"))
            }
        }
        .padding()
    }

    // MARK: - Basic Tab

    private var basicTab: some View {
        ScrollView {
            Form {
                TextField(String(localized: "proxy.localIP"), text: $draft.localIP)
                TextField(String(localized: "proxy.localPort"), value: $draft.localPort, format: .number)

                if ["tcp", "udp"].contains(draft.type) {
                    TextField(String(localized: "proxy.remotePort"), value: $draft.remotePort, format: .number)
                }

                if ["xtcp", "stcp", "sudp"].contains(draft.type) {
                    Picker(String(localized: "proxy.role"), selection: $draft.role) {
                        Text("server").tag("server")
                        Text("visitor").tag("visitor")
                    }
                    TextField(String(localized: "proxy.secretKey"), text: $draft.secretKey)
                    ListEditor(title: String(localized: "proxy.allowUsers"), items: $draft.allowUsers)

                    if draft.role == "visitor" {
                        TextField(String(localized: "proxy.bindAddr"), text: $draft.bindAddr)
                        HStack {
                            Text(String(localized: "proxy.bindPort"))
                            Stepper(value: $draft.bindPort, in: 0...65535) {
                                TextField("", value: $draft.bindPort, format: .number)
                                    .frame(width: 80)
                            }
                        }
                        TextField(String(localized: "proxy.serverName"), text: $draft.serverName)
                        TextField(String(localized: "proxy.serverUser"), text: $draft.serverUser)
                    }
                }

                if ["http", "https", "tcpmux"].contains(draft.type) {
                    TextField(String(localized: "proxy.subdomain"), text: $draft.subdomain)
                    ListEditor(title: String(localized: "proxy.customDomains"), items: $draft.customDomains)

                    if ["http", "https"].contains(draft.type) {
                        ListEditor(title: String(localized: "proxy.locations"), items: $draft.locations)
                    }

                    if draft.type == "tcpmux" {
                        TextField(String(localized: "proxy.multiplexer"), text: $draft.multiplexer)
                    }

                    TextField(String(localized: "proxy.routeByHTTPUser"), text: $draft.routeByHTTPUser)
                }
            }
            .padding()
        }
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        ScrollView {
            Form {
                Section(String(localized: "proxy.bandwidth")) {
                    HStack {
                        Text(String(localized: "proxy.bandwidthLimit"))
                        Stepper(value: $draft.bandwidth.limit, in: 0...100000) {
                            TextField("", value: $draft.bandwidth.limit, format: .number)
                                .frame(width: 80)
                        }
                        Picker("", selection: $draft.bandwidth.unit) {
                            Text("MB").tag("MB")
                            Text("KB").tag("KB")
                        }
                        .frame(width: 80)
                    }
                    Picker(String(localized: "proxy.bandwidthMode"), selection: $draft.bandwidth.mode) {
                        Text("client").tag("client")
                        Text("server").tag("server")
                    }
                }

                Section(String(localized: "proxy.transport")) {
                    TextField(String(localized: "proxy.proxyProtocolVersion"), text: $draft.proxyProtocolVersion)
                    TextField(String(localized: "proxy.transportField"), text: $draft.transport)
                    Toggle(String(localized: "proxy.keepTunnel"), isOn: $draft.keepTunnel)
                    Toggle(String(localized: "proxy.useEncryption"), isOn: $draft.useEncryption)
                    Toggle(String(localized: "proxy.useCompression"), isOn: $draft.useCompression)
                    Toggle(String(localized: "proxy.http2"), isOn: $draft.http2)
                }

                Section(String(localized: "proxy.retry")) {
                    TextField(String(localized: "proxy.fallbackTo"), text: $draft.fallbackTo)
                    HStack {
                        Text(String(localized: "proxy.fallbackTimeout"))
                        Stepper(value: $draft.fallbackTimeout, in: 0...3600) {
                            TextField("", value: $draft.fallbackTimeout, format: .number)
                                .frame(width: 60)
                        }
                    }
                    HStack {
                        Text(String(localized: "proxy.maxRetriesPerHour"))
                        Stepper(value: $draft.maxRetriesPerHour, in: 0...1000) {
                            TextField("", value: $draft.maxRetriesPerHour, format: .number)
                                .frame(width: 60)
                        }
                    }
                    HStack {
                        Text(String(localized: "proxy.minRetryInterval"))
                        Stepper(value: $draft.minRetryInterval, in: 0...3600) {
                            TextField("", value: $draft.minRetryInterval, format: .number)
                                .frame(width: 60)
                        }
                    }
                }

                if ["http", "https"].contains(draft.type) {
                    Section(String(localized: "proxy.httpSettings")) {
                        TextField(String(localized: "proxy.httpUser"), text: $draft.httpUser)
                        SecureField(String(localized: "proxy.httpPwd"), text: $draft.httpPwd)
                        TextField(String(localized: "proxy.hostHeaderRewrite"), text: $draft.hostHeaderRewrite)
                        KeyValueEditor(
                            title: String(localized: "proxy.requestHeaders"),
                            pairs: $draft.requestHeaders
                        )
                        KeyValueEditor(
                            title: String(localized: "proxy.responseHeaders"),
                            pairs: $draft.responseHeaders
                        )
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Plugin Tab

    private var pluginTab: some View {
        ScrollView {
            Form {
                Picker(String(localized: "proxy.plugin"), selection: $draft.plugin.name) {
                    Text(String(localized: "proxy.plugin.none")).tag("")
                    ForEach(Constants.pluginTypes, id: \.self) { plugin in
                        Text(plugin).tag(plugin)
                    }
                }

                if !draft.plugin.name.isEmpty {
                    pluginFields
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var pluginFields: some View {
        let name = draft.plugin.name

        if ["http2http", "http2https", "https2http", "https2https", "tls2raw"].contains(name) {
            TextField(String(localized: "proxy.plugin.localAddr"), text: $draft.plugin.localAddr)
        }

        if ["http2http", "http2https", "https2http", "https2https"].contains(name) {
            TextField(String(localized: "proxy.plugin.hostHeaderRewrite"), text: $draft.plugin.hostHeaderRewrite)
            KeyValueEditor(
                title: String(localized: "proxy.plugin.requestHeaders"),
                pairs: $draft.plugin.requestHeaders
            )
        }

        if ["https2http", "https2https", "tls2raw"].contains(name) {
            BrowseField(label: String(localized: "proxy.plugin.tlsCertFile"), path: $draft.plugin.tlsCertFile)
            BrowseField(label: String(localized: "proxy.plugin.tlsKeyFile"), path: $draft.plugin.tlsKeyFile)
        }

        if name == "tls2raw" {
            BrowseField(label: String(localized: "proxy.plugin.tlsTrustedCaFile"), path: $draft.plugin.tlsTrustedCaFile)
        }

        if name == "http_proxy" {
            TextField(String(localized: "proxy.plugin.httpUser"), text: $draft.plugin.httpUser)
            SecureField(String(localized: "proxy.plugin.httpPwd"), text: $draft.plugin.httpPwd)
        }

        if name == "socks5" {
            TextField(String(localized: "proxy.plugin.socks5User"), text: $draft.plugin.socks5User)
            SecureField(String(localized: "proxy.plugin.socks5Pwd"), text: $draft.plugin.socks5Pwd)
        }

        if name == "static_file" {
            BrowseField(label: String(localized: "proxy.plugin.localPath"), path: $draft.plugin.localPath, canChooseDirectories: true)
            TextField(String(localized: "proxy.plugin.stripPrefix"), text: $draft.plugin.stripPrefix)
            TextField(String(localized: "proxy.plugin.staticFileUser"), text: $draft.plugin.staticFileUser)
            SecureField(String(localized: "proxy.plugin.staticFilePwd"), text: $draft.plugin.staticFilePwd)
        }

        if name == "unix_domain_socket" {
            BrowseField(label: String(localized: "proxy.plugin.unixPath"), path: $draft.plugin.unixPath)
        }
    }

    // MARK: - Load Balance Tab

    private var loadBalanceTab: some View {
        Form {
            TextField(String(localized: "proxy.loadBalance.group"), text: $draft.loadBalance.group)
            TextField(String(localized: "proxy.loadBalance.groupKey"), text: $draft.loadBalance.groupKey)
        }
        .padding()
    }

    // MARK: - Health Check Tab

    private var healthCheckTab: some View {
        Form {
            Picker(String(localized: "proxy.healthCheck.type"), selection: $draft.healthCheck.type) {
                Text(String(localized: "proxy.healthCheck.none")).tag("")
                Text("tcp").tag("tcp")
                Text("http").tag("http")
            }

            if !draft.healthCheck.type.isEmpty {
                if draft.healthCheck.type == "http" {
                    TextField(String(localized: "proxy.healthCheck.url"), text: $draft.healthCheck.url)
                }

                HStack {
                    Text(String(localized: "proxy.healthCheck.timeout"))
                    Stepper(value: $draft.healthCheck.timeout, in: 0...300) {
                        TextField("", value: $draft.healthCheck.timeout, format: .number)
                            .frame(width: 60)
                    }
                    Text(String(localized: "common.seconds"))
                }

                HStack {
                    Text(String(localized: "proxy.healthCheck.interval"))
                    Stepper(value: $draft.healthCheck.interval, in: 0...3600) {
                        TextField("", value: $draft.healthCheck.interval, format: .number)
                            .frame(width: 60)
                    }
                    Text(String(localized: "common.seconds"))
                }

                HStack {
                    Text(String(localized: "proxy.healthCheck.maxFailed"))
                    Stepper(value: $draft.healthCheck.maxFailed, in: 0...100) {
                        TextField("", value: $draft.healthCheck.maxFailed, format: .number)
                            .frame(width: 60)
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Metadata Tab

    private var metadataTab: some View {
        VStack {
            KeyValueEditor(
                title: String(localized: "proxy.metadatas"),
                pairs: $draft.metadatas
            )

            if !isLegacyFormat {
                Divider()
                KeyValueEditor(
                    title: String(localized: "proxy.annotations"),
                    pairs: $draft.annotations
                )
            }
        }
        .padding()
    }

    // MARK: - Validation & Save

    private func save() {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = String(localized: "proxy.error.nameRequired")
            return
        }
        validationError = nil
        proxy = draft
        onSave(draft)
        isPresented = false
    }
}
