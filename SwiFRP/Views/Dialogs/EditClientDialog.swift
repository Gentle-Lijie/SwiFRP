import SwiftUI

struct EditClientDialog: View {
    @Binding var config: ClientConfig
    @Binding var isPresented: Bool
    var onSave: (ClientConfig) -> Void

    @State private var draft: ClientConfig = ClientConfig(name: "")
    @State private var selectedTab = 0
    @State private var validationError: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                basicTab.tag(0).tabItem { Text(String(localized: "client.tab.basic")) }
                authTab.tag(1).tabItem { Text(String(localized: "client.tab.auth")) }
                logTab.tag(2).tabItem { Text(String(localized: "client.tab.log")) }
                adminTab.tag(3).tabItem { Text(String(localized: "client.tab.admin")) }
                connectionTab.tag(4).tabItem { Text(String(localized: "client.tab.connection")) }
                tlsTab.tag(5).tabItem { Text(String(localized: "client.tab.tls")) }
                advancedTab.tag(6).tabItem { Text(String(localized: "client.tab.advanced")) }
            }
            .padding()

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
        .frame(minWidth: 580, minHeight: 480)
        .onAppear { draft = config }
    }

    // MARK: - Basic Tab

    private var basicTab: some View {
        Form {
            TextField(String(localized: "client.name"), text: $draft.name)
            TextField(String(localized: "client.serverAddr"), text: $draft.serverAddr)
            HStack {
                Text(String(localized: "client.serverPort"))
                Stepper(value: $draft.serverPort, in: 0...65535) {
                    TextField("", value: $draft.serverPort, format: .number)
                        .frame(width: 80)
                }
            }
            TextField(String(localized: "client.user"), text: $draft.user)
            TextField(String(localized: "client.stunServer"), text: $draft.natHoleSTUNServer)
        }
        .padding()
    }

    // MARK: - Auth Tab

    private var authTab: some View {
        Form {
            Picker(String(localized: "client.authMethod"), selection: $draft.authMethod) {
                Text(String(localized: "client.auth.none")).tag("")
                ForEach(Constants.authMethods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }

            if draft.authMethod == "token" {
                TextField(String(localized: "client.token"), text: $draft.token)
                BrowseField(label: String(localized: "client.tokenFile"), path: $draft.tokenFile)
            }

            if draft.authMethod == "oidc" {
                TextField(String(localized: "client.oidcClientID"), text: $draft.oidcClientID)
                SecureField(String(localized: "client.oidcClientSecret"), text: $draft.oidcClientSecret)
                TextField(String(localized: "client.oidcAudience"), text: $draft.oidcAudience)
                TextField(String(localized: "client.oidcScope"), text: $draft.oidcScope)
                TextField(String(localized: "client.oidcTokenEndpoint"), text: $draft.oidcTokenEndpoint)
                TextField(String(localized: "client.oidcProxyURL"), text: $draft.oidcProxyURL)
                BrowseField(label: String(localized: "client.oidcTLSCA"), path: $draft.oidcTLSCA)
                Toggle(String(localized: "client.oidcSkipVerify"), isOn: $draft.oidcSkipVerify)
            }

            Section(String(localized: "client.authScope")) {
                Toggle(String(localized: "client.authHeartbeat"), isOn: $draft.authHeartbeat)
                Toggle(String(localized: "client.authNewWorkConn"), isOn: $draft.authNewWorkConn)
            }
        }
        .padding()
    }

    // MARK: - Log Tab

    private var logTab: some View {
        Form {
            Picker(String(localized: "client.logLevel"), selection: $draft.logLevel) {
                ForEach(Constants.logLevels, id: \.self) { level in
                    Text(level).tag(level)
                }
            }

            Stepper(
                String(localized: "client.logMaxDays") + ": \(draft.logMaxDays)",
                value: $draft.logMaxDays, in: 1...365
            )
        }
        .padding()
    }

    // MARK: - Admin Tab

    private var adminTab: some View {
        Form {
            TextField(String(localized: "client.adminAddr"), text: $draft.adminAddr)
            HStack {
                Text(String(localized: "client.adminPort"))
                Stepper(value: $draft.adminPort, in: 0...65535) {
                    TextField("", value: $draft.adminPort, format: .number)
                        .frame(width: 80)
                }
            }
            Toggle(String(localized: "client.adminTLS"), isOn: $draft.adminTLS)
            TextField(String(localized: "client.adminUser"), text: $draft.adminUser)
            SecureField(String(localized: "client.adminPwd"), text: $draft.adminPwd)
            BrowseField(label: String(localized: "client.assetsDir"), path: $draft.assetsDir, canChooseDirectories: true)

            Divider()

            Text(String(localized: "client.autoDelete"))
                .font(.headline)

            Picker(String(localized: "client.deleteMethod"), selection: $draft.autoDelete.deleteMethod) {
                Text(String(localized: "client.delete.none")).tag(DeleteMethod.none)
                Text(String(localized: "client.delete.absolute")).tag(DeleteMethod.absolute)
                Text(String(localized: "client.delete.relative")).tag(DeleteMethod.relative)
            }
            .pickerStyle(.radioGroup)

            if draft.autoDelete.deleteMethod == .absolute {
                DatePicker(
                    String(localized: "client.deleteAfterDate"),
                    selection: $draft.autoDelete.deleteAfterDate,
                    displayedComponents: .date
                )
            }

            if draft.autoDelete.deleteMethod == .relative {
                Stepper(
                    String(localized: "client.deleteAfterDays") + ": \(draft.autoDelete.deleteAfterDays)",
                    value: $draft.autoDelete.deleteAfterDays, in: 1...3650
                )
            }
        }
        .padding()
    }

    // MARK: - Connection Tab

    private var connectionTab: some View {
        Form {
            Picker(String(localized: "client.protocol"), selection: $draft.protocol) {
                ForEach(Constants.protocols, id: \.self) { proto in
                    Text(proto).tag(proto)
                }
            }

            HStack {
                Text(String(localized: "client.dialTimeout"))
                Stepper(value: $draft.dialTimeout, in: 1...300) {
                    TextField("", value: $draft.dialTimeout, format: .number)
                        .frame(width: 60)
                }
                Text(String(localized: "common.seconds"))
            }

            HStack {
                Text(String(localized: "client.keepalivePeriod"))
                Stepper(value: $draft.keepalivePeriod, in: 0...3600) {
                    TextField("", value: $draft.keepalivePeriod, format: .number)
                        .frame(width: 60)
                }
                Text(String(localized: "common.seconds"))
            }

            HStack {
                Text(String(localized: "client.connectPoolSize"))
                Stepper(value: $draft.connectPoolSize, in: 0...100) {
                    TextField("", value: $draft.connectPoolSize, format: .number)
                        .frame(width: 60)
                }
            }

            if draft.protocol == "quic" {
                Divider()
                Text(String(localized: "client.quicSettings"))
                    .font(.headline)

                HStack {
                    Text(String(localized: "client.quicKeepalivePeriod"))
                    Stepper(value: $draft.quicKeepalivePeriod, in: 0...3600) {
                        TextField("", value: $draft.quicKeepalivePeriod, format: .number)
                            .frame(width: 60)
                    }
                    Text(String(localized: "common.seconds"))
                }

                HStack {
                    Text(String(localized: "client.quicMaxIdleTimeout"))
                    Stepper(value: $draft.quicMaxIdleTimeout, in: 0...3600) {
                        TextField("", value: $draft.quicMaxIdleTimeout, format: .number)
                            .frame(width: 60)
                    }
                    Text(String(localized: "common.seconds"))
                }

                HStack {
                    Text(String(localized: "client.quicMaxIncomingStreams"))
                    Stepper(value: $draft.quicMaxIncomingStreams, in: 0...10000) {
                        TextField("", value: $draft.quicMaxIncomingStreams, format: .number)
                            .frame(width: 60)
                    }
                }
            }

            Divider()

            HStack {
                Text(String(localized: "client.heartbeatInterval"))
                Stepper(value: $draft.heartbeatInterval, in: 0...3600) {
                    TextField("", value: $draft.heartbeatInterval, format: .number)
                        .frame(width: 60)
                }
                Text(String(localized: "common.seconds"))
            }

            HStack {
                Text(String(localized: "client.heartbeatTimeout"))
                Stepper(value: $draft.heartbeatTimeout, in: 0...3600) {
                    TextField("", value: $draft.heartbeatTimeout, format: .number)
                        .frame(width: 60)
                }
                Text(String(localized: "common.seconds"))
            }
        }
        .padding()
    }

    // MARK: - TLS Tab

    private var tlsTab: some View {
        Form {
            Toggle(String(localized: "client.tlsEnable"), isOn: $draft.tlsEnable)
            TextField(String(localized: "client.tlsServerName"), text: $draft.tlsServerName)
            BrowseField(label: String(localized: "client.tlsCertFile"), path: $draft.tlsCertFile)
            BrowseField(label: String(localized: "client.tlsKeyFile"), path: $draft.tlsKeyFile)
            BrowseField(label: String(localized: "client.tlsTrustedCaFile"), path: $draft.tlsTrustedCaFile)
            Toggle(String(localized: "client.tlsDisableCustomFirstByte"), isOn: $draft.tlsDisableCustomFirstByte)
        }
        .padding()
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            TextField(String(localized: "client.dnsServer"), text: $draft.dnsServer)
            TextField(String(localized: "client.connectServerLocalIP"), text: $draft.connectServerLocalIP)

            Toggle(String(localized: "client.tcpMux"), isOn: $draft.tcpMux)

            if draft.tcpMux {
                HStack {
                    Text(String(localized: "client.tcpMuxKeepAliveInterval"))
                    Stepper(value: $draft.tcpMuxKeepAliveInterval, in: 0...3600) {
                        TextField("", value: $draft.tcpMuxKeepAliveInterval, format: .number)
                            .frame(width: 60)
                    }
                    Text(String(localized: "common.seconds"))
                }
            }

            Toggle(String(localized: "client.loginFailExit"), isOn: $draft.loginFailExit)
            Toggle(String(localized: "client.manualStart"), isOn: $draft.manualStart)
            Toggle(String(localized: "client.legacyFormat"), isOn: $draft.legacyFormat)

            Divider()

            KeyValueEditor(
                title: String(localized: "client.metadatas"),
                pairs: $draft.metadatas
            )
        }
        .padding()
    }

    // MARK: - Validation & Save

    private func save() {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = String(localized: "client.error.nameRequired")
            selectedTab = 0
            return
        }
        if draft.serverAddr.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = String(localized: "client.error.serverAddrRequired")
            selectedTab = 0
            return
        }
        validationError = nil
        config = draft
        onSave(draft)
        isPresented = false
    }
}
