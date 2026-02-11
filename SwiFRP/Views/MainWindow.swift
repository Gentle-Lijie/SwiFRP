import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            ConfigPageView()
                .tabItem {
                    Label(String(localized: "tab.configuration"), systemImage: "gearshape.2")
                }
                .tag(AppTab.configuration)

            LogPageView()
                .tabItem {
                    Label(String(localized: "tab.log"), systemImage: "doc.text")
                }
                .tag(AppTab.log)

            PreferencesPageView()
                .tabItem {
                    Label(String(localized: "tab.preferences"), systemImage: "slider.horizontal.3")
                }
                .tag(AppTab.preferences)

            AboutPageView()
                .tabItem {
                    if appState.hasNewVersion {
                        Label(String(localized: "tab.about.newVersion"), systemImage: "info.circle.fill")
                    } else {
                        Label(String(localized: "tab.about"), systemImage: "info.circle")
                    }
                }
                .tag(AppTab.about)
        }
        .sheet(isPresented: Binding(
            get: { !appState.isPasswordVerified && !appState.appConfig.password.isEmpty },
            set: { _ in }
        )) {
            PasswordVerifyView()
        }
    }
}

struct PasswordVerifyView: View {
    @EnvironmentObject var appState: AppState
    @State private var password: String = ""
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text(String(localized: "password.enterPassword"))
                .font(.headline)

            SecureField(String(localized: "password.placeholder"), text: $password)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
                .onSubmit { verify() }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }

            HStack {
                Button(String(localized: "common.quit")) {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut(.cancelAction)

                Button(String(localized: "common.unlock")) {
                    verify()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(40)
        .frame(width: 350)
    }

    private func verify() {
        let hash = StringUtils.sha256Hash(password)
        if hash == appState.appConfig.password {
            appState.isPasswordVerified = true
        } else {
            errorMessage = String(localized: "password.incorrect")
        }
    }
}
