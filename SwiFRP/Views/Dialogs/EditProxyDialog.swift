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
                basicTab.tag(0).tabItem { Text(L("proxy.tab.basic")) }
                advancedTab.tag(1).tabItem { Text(L("proxy.tab.advanced")) }
                pluginTab.tag(2).tabItem { Text(L("proxy.tab.plugin")) }
                loadBalanceTab.tag(3).tabItem { Text(L("proxy.tab.loadBalance")) }
                healthCheckTab.tag(4).tabItem { Text(L("proxy.tab.healthCheck")) }
                metadataTab.tag(5).tabItem { Text(L("proxy.tab.metadata")) }
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
                Button(L("common.cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button(L("common.save")) {
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
            TextField(L("proxy.name"), text: $draft.name)
                .textFieldStyle(.roundedBorder)

            Button {
                draft.name = StringUtils.generateRandomName()
            } label: {
                Image(systemName: "dice")
            }
            .help(L("proxy.randomName"))

            Picker(L("proxy.type"), selection: $draft.type) {
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
                .help(L("proxy.annotations"))
            }
        }
        .padding()
    }

    // MARK: - Basic Tab

    private var basicTab: some View {
        ScrollView {
            Form {
                TextField(L("proxy.localIP"), text: $draft.localIP)
                TextField(L("proxy.localPort"), value: $draft.localPort, format: .number)

                if ["tcp", "udp"].contains(draft.type) {
                    TextField(L("proxy.remotePort"), value: $draft.remotePort, format: .number)
                }

                if ["xtcp", "stcp", "sudp"].contains(draft.type) {
                    Picker(L("proxy.role"), selection: $draft.role) {
                        Text("server").tag("server")
                        Text("visitor").tag("visitor")
                    }
                    TextField(L("proxy.secretKey"), text: $draft.secretKey)
                    ListEditor(title: L("proxy.allowUsers"), items: $draft.allowUsers)

                    if draft.role == "visitor" {
                        TextField(L("proxy.bindAddr"), text: $draft.bindAddr)
                        HStack {
                            Text(L("proxy.bindPort"))
                            Stepper(value: $draft.bindPort, in: 0...65535) {
                                TextField("", value: $draft.bindPort, format: .number)
                                    .frame(width: 80)
                            }
                        }
                        TextField(L("proxy.serverName"), text: $draft.serverName)
                        TextField(L("proxy.serverUser"), text: $draft.serverUser)
                    }
                }

                if ["http", "https", "tcpmux"].contains(draft.type) {
                    TextField(L("proxy.subdomain"), text: $draft.subdomain)
                    ListEditor(title: L("proxy.customDomains"), items: $draft.customDomains)

                    if ["http", "https"].contains(draft.type) {
                        ListEditor(title: L("proxy.locations"), items: $draft.locations)
                    }

                    if draft.type == "tcpmux" {
                        TextField(L("proxy.multiplexer"), text: $draft.multiplexer)
                    }

                    TextField(L("proxy.routeByHTTPUser"), text: $draft.routeByHTTPUser)
                }
            }
            .padding()
        }
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        ScrollView {
            Form {
                Section(L("proxy.bandwidth")) {
                    HStack {
                        Text(L("proxy.bandwidthLimit"))
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
                    Picker(L("proxy.bandwidthMode"), selection: $draft.bandwidth.mode) {
                        Text("client").tag("client")
                        Text("server").tag("server")
                    }
                }

                Section(L("proxy.transport")) {
                    TextField(L("proxy.proxyProtocolVersion"), text: $draft.proxyProtocolVersion)
                    TextField(L("proxy.transportField"), text: $draft.transport)
                    Toggle(L("proxy.keepTunnel"), isOn: $draft.keepTunnel)
                    Toggle(L("proxy.useEncryption"), isOn: $draft.useEncryption)
                    Toggle(L("proxy.useCompression"), isOn: $draft.useCompression)
                    Toggle(L("proxy.http2"), isOn: $draft.http2)
                }

                Section(L("proxy.retry")) {
                    TextField(L("proxy.fallbackTo"), text: $draft.fallbackTo)
                    HStack {
                        Text(L("proxy.fallbackTimeout"))
                        Stepper(value: $draft.fallbackTimeout, in: 0...3600) {
                            TextField("", value: $draft.fallbackTimeout, format: .number)
                                .frame(width: 60)
                        }
                    }
                    HStack {
                        Text(L("proxy.maxRetriesPerHour"))
                        Stepper(value: $draft.maxRetriesPerHour, in: 0...1000) {
                            TextField("", value: $draft.maxRetriesPerHour, format: .number)
                                .frame(width: 60)
                        }
                    }
                    HStack {
                        Text(L("proxy.minRetryInterval"))
                        Stepper(value: $draft.minRetryInterval, in: 0...3600) {
                            TextField("", value: $draft.minRetryInterval, format: .number)
                                .frame(width: 60)
                        }
                    }
                }

                if ["http", "https"].contains(draft.type) {
                    Section(L("proxy.httpSettings")) {
                        TextField(L("proxy.httpUser"), text: $draft.httpUser)
                        SecureField(L("proxy.httpPwd"), text: $draft.httpPwd)
                        TextField(L("proxy.hostHeaderRewrite"), text: $draft.hostHeaderRewrite)
                        KeyValueEditor(
                            title: L("proxy.requestHeaders"),
                            pairs: $draft.requestHeaders
                        )
                        KeyValueEditor(
                            title: L("proxy.responseHeaders"),
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
                Picker(L("proxy.plugin"), selection: $draft.plugin.name) {
                    Text(L("proxy.plugin.none")).tag("")
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
            TextField(L("proxy.plugin.localAddr"), text: $draft.plugin.localAddr)
        }

        if ["http2http", "http2https", "https2http", "https2https"].contains(name) {
            TextField(L("proxy.plugin.hostHeaderRewrite"), text: $draft.plugin.hostHeaderRewrite)
            KeyValueEditor(
                title: L("proxy.plugin.requestHeaders"),
                pairs: $draft.plugin.requestHeaders
            )
        }

        if ["https2http", "https2https", "tls2raw"].contains(name) {
            BrowseField(label: L("proxy.plugin.tlsCertFile"), path: $draft.plugin.tlsCertFile)
            BrowseField(label: L("proxy.plugin.tlsKeyFile"), path: $draft.plugin.tlsKeyFile)
        }

        if name == "tls2raw" {
            BrowseField(label: L("proxy.plugin.tlsTrustedCaFile"), path: $draft.plugin.tlsTrustedCaFile)
        }

        if name == "http_proxy" {
            TextField(L("proxy.plugin.httpUser"), text: $draft.plugin.httpUser)
            SecureField(L("proxy.plugin.httpPwd"), text: $draft.plugin.httpPwd)
        }

        if name == "socks5" {
            TextField(L("proxy.plugin.socks5User"), text: $draft.plugin.socks5User)
            SecureField(L("proxy.plugin.socks5Pwd"), text: $draft.plugin.socks5Pwd)
        }

        if name == "static_file" {
            BrowseField(label: L("proxy.plugin.localPath"), path: $draft.plugin.localPath, canChooseDirectories: true)
            TextField(L("proxy.plugin.stripPrefix"), text: $draft.plugin.stripPrefix)
            TextField(L("proxy.plugin.staticFileUser"), text: $draft.plugin.staticFileUser)
            SecureField(L("proxy.plugin.staticFilePwd"), text: $draft.plugin.staticFilePwd)
        }

        if name == "unix_domain_socket" {
            BrowseField(label: L("proxy.plugin.unixPath"), path: $draft.plugin.unixPath)
        }
    }

    // MARK: - Load Balance Tab

    private var loadBalanceTab: some View {
        Form {
            TextField(L("proxy.loadBalance.group"), text: $draft.loadBalance.group)
            TextField(L("proxy.loadBalance.groupKey"), text: $draft.loadBalance.groupKey)
        }
        .padding()
    }

    // MARK: - Health Check Tab

    private var healthCheckTab: some View {
        Form {
            Picker(L("proxy.healthCheck.type"), selection: $draft.healthCheck.type) {
                Text(L("proxy.healthCheck.none")).tag("")
                Text("tcp").tag("tcp")
                Text("http").tag("http")
            }

            if !draft.healthCheck.type.isEmpty {
                if draft.healthCheck.type == "http" {
                    TextField(L("proxy.healthCheck.url"), text: $draft.healthCheck.url)
                }

                HStack {
                    Text(L("proxy.healthCheck.timeout"))
                    Stepper(value: $draft.healthCheck.timeout, in: 0...300) {
                        TextField("", value: $draft.healthCheck.timeout, format: .number)
                            .frame(width: 60)
                    }
                    Text(L("common.seconds"))
                }

                HStack {
                    Text(L("proxy.healthCheck.interval"))
                    Stepper(value: $draft.healthCheck.interval, in: 0...3600) {
                        TextField("", value: $draft.healthCheck.interval, format: .number)
                            .frame(width: 60)
                    }
                    Text(L("common.seconds"))
                }

                HStack {
                    Text(L("proxy.healthCheck.maxFailed"))
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
                title: L("proxy.metadatas"),
                pairs: $draft.metadatas
            )

            if !isLegacyFormat {
                Divider()
                KeyValueEditor(
                    title: L("proxy.annotations"),
                    pairs: $draft.annotations
                )
            }
        }
        .padding()
    }

    // MARK: - Validation & Save

    private func save() {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = L("proxy.error.nameRequired")
            return
        }
        validationError = nil
        proxy = draft
        onSave(draft)
        isPresented = false
    }
}
