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
                basicTab.tag(0).tabItem { Text(L("client.tab.basic")) }
                authTab.tag(1).tabItem { Text(L("client.tab.auth")) }
                logTab.tag(2).tabItem { Text(L("client.tab.log")) }
                adminTab.tag(3).tabItem { Text(L("client.tab.admin")) }
                connectionTab.tag(4).tabItem { Text(L("client.tab.connection")) }
                tlsTab.tag(5).tabItem { Text(L("client.tab.tls")) }
                advancedTab.tag(6).tabItem { Text(L("client.tab.advanced")) }
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
        .frame(minWidth: 580, minHeight: 480)
        .onAppear { draft = config }
    }

    // MARK: - Basic Tab

    private var basicTab: some View {
        Form {
            TextField(L("client.name"), text: $draft.name)
            TextField(L("client.serverAddr"), text: $draft.serverAddr)
            HStack {
                Text(L("client.serverPort"))
                Stepper(value: $draft.serverPort, in: 0...65535) {
                    TextField("", value: $draft.serverPort, format: .number)
                        .frame(width: 80)
                }
            }
            TextField(L("client.user"), text: $draft.user)
            TextField(L("client.stunServer"), text: $draft.natHoleSTUNServer)
        }
        .padding()
    }

    // MARK: - Auth Tab

    private var authTab: some View {
        Form {
            Picker(L("client.authMethod"), selection: $draft.authMethod) {
                Text(L("client.auth.none")).tag("")
                ForEach(Constants.authMethods, id: \.self) { method in
                    Text(method).tag(method)
                }
            }

            if draft.authMethod == "token" {
                TextField(L("client.token"), text: $draft.token)
                BrowseField(label: L("client.tokenFile"), path: $draft.tokenFile)
            }

            if draft.authMethod == "oidc" {
                TextField(L("client.oidcClientID"), text: $draft.oidcClientID)
                SecureField(L("client.oidcClientSecret"), text: $draft.oidcClientSecret)
                TextField(L("client.oidcAudience"), text: $draft.oidcAudience)
                TextField(L("client.oidcScope"), text: $draft.oidcScope)
                TextField(L("client.oidcTokenEndpoint"), text: $draft.oidcTokenEndpoint)
                TextField(L("client.oidcProxyURL"), text: $draft.oidcProxyURL)
                BrowseField(label: L("client.oidcTLSCA"), path: $draft.oidcTLSCA)
                Toggle(L("client.oidcSkipVerify"), isOn: $draft.oidcSkipVerify)
            }

            Section(L("client.authScope")) {
                Toggle(L("client.authHeartbeat"), isOn: $draft.authHeartbeat)
                Toggle(L("client.authNewWorkConn"), isOn: $draft.authNewWorkConn)
            }
        }
        .padding()
    }

    // MARK: - Log Tab

    private var logTab: some View {
        Form {
            Picker(L("client.logLevel"), selection: $draft.logLevel) {
                ForEach(Constants.logLevels, id: \.self) { level in
                    Text(level).tag(level)
                }
            }

            Stepper(
                L("client.logMaxDays") + ": \(draft.logMaxDays)",
                value: $draft.logMaxDays, in: 1...365
            )
        }
        .padding()
    }

    // MARK: - Admin Tab

    private var adminTab: some View {
        Form {
            TextField(L("client.adminAddr"), text: $draft.adminAddr)
            HStack {
                Text(L("client.adminPort"))
                Stepper(value: $draft.adminPort, in: 0...65535) {
                    TextField("", value: $draft.adminPort, format: .number)
                        .frame(width: 80)
                }
            }
            Toggle(L("client.adminTLS"), isOn: $draft.adminTLS)
            TextField(L("client.adminUser"), text: $draft.adminUser)
            SecureField(L("client.adminPwd"), text: $draft.adminPwd)
            BrowseField(label: L("client.assetsDir"), path: $draft.assetsDir, canChooseDirectories: true)

            Divider()

            Text(L("client.autoDelete"))
                .font(.headline)

            Picker(L("client.deleteMethod"), selection: $draft.autoDelete.deleteMethod) {
                Text(L("client.delete.none")).tag(DeleteMethod.none)
                Text(L("client.delete.absolute")).tag(DeleteMethod.absolute)
                Text(L("client.delete.relative")).tag(DeleteMethod.relative)
            }
            .pickerStyle(.radioGroup)

            if draft.autoDelete.deleteMethod == .absolute {
                DatePicker(
                    L("client.deleteAfterDate"),
                    selection: $draft.autoDelete.deleteAfterDate,
                    displayedComponents: .date
                )
            }

            if draft.autoDelete.deleteMethod == .relative {
                Stepper(
                    L("client.deleteAfterDays") + ": \(draft.autoDelete.deleteAfterDays)",
                    value: $draft.autoDelete.deleteAfterDays, in: 1...3650
                )
            }
        }
        .padding()
    }

    // MARK: - Connection Tab

    private var connectionTab: some View {
        Form {
            Picker(L("client.protocol"), selection: $draft.protocol) {
                ForEach(Constants.protocols, id: \.self) { proto in
                    Text(proto).tag(proto)
                }
            }

            HStack {
                Text(L("client.dialTimeout"))
                Stepper(value: $draft.dialTimeout, in: 1...300) {
                    TextField("", value: $draft.dialTimeout, format: .number)
                        .frame(width: 60)
                }
                Text(L("common.seconds"))
            }

            HStack {
                Text(L("client.keepalivePeriod"))
                Stepper(value: $draft.keepalivePeriod, in: 0...3600) {
                    TextField("", value: $draft.keepalivePeriod, format: .number)
                        .frame(width: 60)
                }
                Text(L("common.seconds"))
            }

            HStack {
                Text(L("client.connectPoolSize"))
                Stepper(value: $draft.connectPoolSize, in: 0...100) {
                    TextField("", value: $draft.connectPoolSize, format: .number)
                        .frame(width: 60)
                }
            }

            if draft.protocol == "quic" {
                Divider()
                Text(L("client.quicSettings"))
                    .font(.headline)

                HStack {
                    Text(L("client.quicKeepalivePeriod"))
                    Stepper(value: $draft.quicKeepalivePeriod, in: 0...3600) {
                        TextField("", value: $draft.quicKeepalivePeriod, format: .number)
                            .frame(width: 60)
                    }
                    Text(L("common.seconds"))
                }

                HStack {
                    Text(L("client.quicMaxIdleTimeout"))
                    Stepper(value: $draft.quicMaxIdleTimeout, in: 0...3600) {
                        TextField("", value: $draft.quicMaxIdleTimeout, format: .number)
                            .frame(width: 60)
                    }
                    Text(L("common.seconds"))
                }

                HStack {
                    Text(L("client.quicMaxIncomingStreams"))
                    Stepper(value: $draft.quicMaxIncomingStreams, in: 0...10000) {
                        TextField("", value: $draft.quicMaxIncomingStreams, format: .number)
                            .frame(width: 60)
                    }
                }
            }

            Divider()

            HStack {
                Text(L("client.heartbeatInterval"))
                Stepper(value: $draft.heartbeatInterval, in: 0...3600) {
                    TextField("", value: $draft.heartbeatInterval, format: .number)
                        .frame(width: 60)
                }
                Text(L("common.seconds"))
            }

            HStack {
                Text(L("client.heartbeatTimeout"))
                Stepper(value: $draft.heartbeatTimeout, in: 0...3600) {
                    TextField("", value: $draft.heartbeatTimeout, format: .number)
                        .frame(width: 60)
                }
                Text(L("common.seconds"))
            }
        }
        .padding()
    }

    // MARK: - TLS Tab

    private var tlsTab: some View {
        Form {
            Toggle(L("client.tlsEnable"), isOn: $draft.tlsEnable)
            TextField(L("client.tlsServerName"), text: $draft.tlsServerName)
            BrowseField(label: L("client.tlsCertFile"), path: $draft.tlsCertFile)
            BrowseField(label: L("client.tlsKeyFile"), path: $draft.tlsKeyFile)
            BrowseField(label: L("client.tlsTrustedCaFile"), path: $draft.tlsTrustedCaFile)
            Toggle(L("client.tlsDisableCustomFirstByte"), isOn: $draft.tlsDisableCustomFirstByte)
        }
        .padding()
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            TextField(L("client.dnsServer"), text: $draft.dnsServer)
            TextField(L("client.connectServerLocalIP"), text: $draft.connectServerLocalIP)

            Toggle(L("client.tcpMux"), isOn: $draft.tcpMux)

            if draft.tcpMux {
                HStack {
                    Text(L("client.tcpMuxKeepAliveInterval"))
                    Stepper(value: $draft.tcpMuxKeepAliveInterval, in: 0...3600) {
                        TextField("", value: $draft.tcpMuxKeepAliveInterval, format: .number)
                            .frame(width: 60)
                    }
                    Text(L("common.seconds"))
                }
            }

            Toggle(L("client.loginFailExit"), isOn: $draft.loginFailExit)
            Toggle(L("client.manualStart"), isOn: $draft.manualStart)
            Toggle(L("client.legacyFormat"), isOn: $draft.legacyFormat)

            Divider()

            KeyValueEditor(
                title: L("client.metadatas"),
                pairs: $draft.metadatas
            )
        }
        .padding()
    }

    // MARK: - Validation & Save

    private func save() {
        if draft.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = L("client.error.nameRequired")
            selectedTab = 0
            return
        }
        if draft.serverAddr.trimmingCharacters(in: .whitespaces).isEmpty {
            validationError = L("client.error.serverAddrRequired")
            selectedTab = 0
            return
        }
        validationError = nil
        config = draft
        onSave(draft)
        isPresented = false
    }
}
