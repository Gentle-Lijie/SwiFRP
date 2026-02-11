import SwiftUI

struct PreferencesPageView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: PreferencesViewModel

    init() {
        // Defer initialization until appState is available
        _viewModel = StateObject(wrappedValue: PreferencesViewModel(appState: AppState.shared))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                passwordSection
                languageSection
                advancedSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $viewModel.isShowingChangePassword) {
            changePasswordSheet
        }
        .sheet(isPresented: $viewModel.isShowingAdvancedSettings) {
            advancedSettingsSheet
        }
    }

    // MARK: - Password Section

    private var passwordSection: some View {
        GroupBox(String(localized: "preferences.password")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(String(localized: "preferences.password.enable"), isOn: $viewModel.isPasswordEnabled)
                    .onChange(of: viewModel.isPasswordEnabled) { enabled in
                        if !enabled {
                            viewModel.isShowingChangePassword = true
                        }
                    }

                if viewModel.isPasswordEnabled {
                    if appState.appConfig.password.isEmpty {
                        SecureField(String(localized: "preferences.password.new"), text: $viewModel.newPassword)
                            .frame(width: 250)
                        SecureField(String(localized: "preferences.password.confirm"), text: $viewModel.confirmPassword)
                            .frame(width: 250)

                        if let error = viewModel.passwordError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }

                        Button(String(localized: "preferences.password.set")) {
                            viewModel.enablePassword()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(String(localized: "preferences.password.change")) {
                            viewModel.isShowingChangePassword = true
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Language Section

    private var languageSection: some View {
        GroupBox(String(localized: "preferences.language")) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(String(localized: "preferences.language.select"), selection: $viewModel.selectedLanguage) {
                    ForEach(PreferencesViewModel.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .frame(width: 250)
                .onChange(of: viewModel.selectedLanguage) { _ in
                    viewModel.saveLanguage()
                }

                Text(String(localized: "preferences.language.restartNote"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        GroupBox(String(localized: "preferences.advanced")) {
            Button(String(localized: "preferences.advanced.open")) {
                viewModel.isShowingAdvancedSettings = true
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Change Password Sheet

    private var changePasswordSheet: some View {
        VStack(spacing: 16) {
            Text(String(localized: "preferences.password.changeTitle"))
                .font(.headline)

            if !appState.appConfig.password.isEmpty {
                SecureField(String(localized: "preferences.password.current"), text: $viewModel.currentPassword)
                    .frame(width: 250)
            }

            if viewModel.isPasswordEnabled {
                SecureField(String(localized: "preferences.password.new"), text: $viewModel.newPassword)
                    .frame(width: 250)
                SecureField(String(localized: "preferences.password.confirm"), text: $viewModel.confirmPassword)
                    .frame(width: 250)
            }

            if let error = viewModel.passwordError {
                Text(error).foregroundColor(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button(String(localized: "common.cancel")) {
                    viewModel.isShowingChangePassword = false
                }
                .keyboardShortcut(.cancelAction)

                if viewModel.isPasswordEnabled {
                    Button(String(localized: "common.save")) {
                        viewModel.changePassword()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(String(localized: "preferences.password.disable")) {
                        viewModel.disablePassword()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(width: 350)
    }

    // MARK: - Advanced Settings Sheet

    private var advancedSettingsSheet: some View {
        VStack(spacing: 12) {
            Text(String(localized: "preferences.advanced.title"))
                .font(.headline)

            ScrollView {
                Form {
                    Toggle(String(localized: "preferences.advanced.checkUpdate"), isOn: $appState.appConfig.checkUpdate)

                    Divider()

                    Text(String(localized: "preferences.advanced.defaults"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker(String(localized: "preferences.advanced.protocol"), selection: $appState.appConfig.defaults.protocol) {
                        ForEach(Constants.protocols, id: \.self) { proto in
                            Text(proto).tag(proto)
                        }
                    }

                    TextField(String(localized: "preferences.advanced.user"), text: $appState.appConfig.defaults.user)

                    Picker(String(localized: "preferences.advanced.logLevel"), selection: $appState.appConfig.defaults.logLevel) {
                        ForEach(Constants.logLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }

                    Stepper(
                        String(localized: "preferences.advanced.logMaxDays") + ": \(appState.appConfig.defaults.logMaxDays)",
                        value: $appState.appConfig.defaults.logMaxDays, in: 1...365
                    )

                    TextField(String(localized: "preferences.advanced.dnsServer"), text: $appState.appConfig.defaults.dnsServer)
                    TextField(String(localized: "preferences.advanced.stunServer"), text: $appState.appConfig.defaults.natHoleSTUNServer)
                    TextField(String(localized: "preferences.advanced.sourceAddr"), text: $appState.appConfig.defaults.connectServerLocalIP)

                    Toggle(String(localized: "preferences.advanced.tcpMux"), isOn: $appState.appConfig.defaults.tcpMux)
                    Toggle(String(localized: "preferences.advanced.tls"), isOn: $appState.appConfig.defaults.tlsEnable)
                    Toggle(String(localized: "preferences.advanced.manualStart"), isOn: $appState.appConfig.defaults.manualStart)
                    Toggle(String(localized: "preferences.advanced.legacyFormat"), isOn: $appState.appConfig.defaults.legacyFormat)
                }
            }
            .frame(maxHeight: 400)

            Divider()

            HStack {
                Spacer()
                Button(String(localized: "common.close")) {
                    appState.saveAppConfig()
                    viewModel.isShowingAdvancedSettings = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 460)
    }
}
