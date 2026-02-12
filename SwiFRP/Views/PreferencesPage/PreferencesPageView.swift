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
        GroupBox(L("preferences.password")) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(L("preferences.password.enable"), isOn: $viewModel.isPasswordEnabled)
                    .onChange(of: viewModel.isPasswordEnabled) { enabled in
                        if !enabled {
                            viewModel.isShowingChangePassword = true
                        }
                    }

                if viewModel.isPasswordEnabled {
                    if appState.appConfig.password.isEmpty {
                        SecureField(L("preferences.password.new"), text: $viewModel.newPassword)
                            .frame(width: 250)
                        SecureField(L("preferences.password.confirm"), text: $viewModel.confirmPassword)
                            .frame(width: 250)

                        if let error = viewModel.passwordError {
                            Text(error).foregroundColor(.red).font(.caption)
                        }

                        Button(L("preferences.password.set")) {
                            viewModel.enablePassword()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button(L("preferences.password.change")) {
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
        GroupBox(L("preferences.language")) {
            VStack(alignment: .leading, spacing: 8) {
                Picker(L("preferences.language.select"), selection: $viewModel.selectedLanguage) {
                    ForEach(PreferencesViewModel.availableLanguages, id: \.code) { lang in
                        Text(lang.name).tag(lang.code)
                    }
                }
                .frame(width: 250)
                .onChange(of: viewModel.selectedLanguage) { _ in
                    viewModel.saveLanguage()
                }

                Text(L("preferences.language.restartNote"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Advanced Section

    private var advancedSection: some View {
        GroupBox(L("preferences.advanced")) {
            Button(L("preferences.advanced.open")) {
                viewModel.isShowingAdvancedSettings = true
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Change Password Sheet

    private var changePasswordSheet: some View {
        VStack(spacing: 16) {
            Text(L("preferences.password.changeTitle"))
                .font(.headline)

            if !appState.appConfig.password.isEmpty {
                SecureField(L("preferences.password.current"), text: $viewModel.currentPassword)
                    .frame(width: 250)
            }

            if viewModel.isPasswordEnabled {
                SecureField(L("preferences.password.new"), text: $viewModel.newPassword)
                    .frame(width: 250)
                SecureField(L("preferences.password.confirm"), text: $viewModel.confirmPassword)
                    .frame(width: 250)
            }

            if let error = viewModel.passwordError {
                Text(error).foregroundColor(.red).font(.caption)
            }

            HStack {
                Spacer()
                Button(L("common.cancel")) {
                    viewModel.isShowingChangePassword = false
                }
                .keyboardShortcut(.cancelAction)

                if viewModel.isPasswordEnabled {
                    Button(L("common.save")) {
                        viewModel.changePassword()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button(L("preferences.password.disable")) {
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
            Text(L("preferences.advanced.title"))
                .font(.headline)

            ScrollView {
                Form {
                    Toggle(L("preferences.advanced.checkUpdate"), isOn: $appState.appConfig.checkUpdate)

                    Divider()

                    Text(L("preferences.advanced.defaults"))
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker(L("preferences.advanced.protocol"), selection: $appState.appConfig.defaults.protocol) {
                        ForEach(Constants.protocols, id: \.self) { proto in
                            Text(proto).tag(proto)
                        }
                    }

                    TextField(L("preferences.advanced.user"), text: $appState.appConfig.defaults.user)

                    Picker(L("preferences.advanced.logLevel"), selection: $appState.appConfig.defaults.logLevel) {
                        ForEach(Constants.logLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }

                    Stepper(
                        L("preferences.advanced.logMaxDays") + ": \(appState.appConfig.defaults.logMaxDays)",
                        value: $appState.appConfig.defaults.logMaxDays, in: 1...365
                    )

                    TextField(L("preferences.advanced.dnsServer"), text: $appState.appConfig.defaults.dnsServer)
                    TextField(L("preferences.advanced.stunServer"), text: $appState.appConfig.defaults.natHoleSTUNServer)
                    TextField(L("preferences.advanced.sourceAddr"), text: $appState.appConfig.defaults.connectServerLocalIP)

                    Toggle(L("preferences.advanced.tcpMux"), isOn: $appState.appConfig.defaults.tcpMux)
                    Toggle(L("preferences.advanced.tls"), isOn: $appState.appConfig.defaults.tlsEnable)
                    Toggle(L("preferences.advanced.manualStart"), isOn: $appState.appConfig.defaults.manualStart)
                    Toggle(L("preferences.advanced.legacyFormat"), isOn: $appState.appConfig.defaults.legacyFormat)
                }
            }
            .frame(maxHeight: 400)

            Divider()

            HStack {
                Spacer()
                Button(L("common.close")) {
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
