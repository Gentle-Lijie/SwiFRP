import SwiftUI
import Combine
import CryptoKit

class PreferencesViewModel: ObservableObject {
    @Published var isPasswordEnabled: Bool
    @Published var isShowingChangePassword = false
    @Published var isShowingAdvancedSettings = false
    @Published var selectedLanguage: String
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmPassword: String = ""
    @Published var passwordError: String? = nil

    static let availableLanguages: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja", "日本語"),
        ("ko", "한국어"),
        ("es", "Español"),
    ]

    private var appState: AppState

    init(appState: AppState) {
        self.appState = appState
        self.isPasswordEnabled = !appState.appConfig.password.isEmpty
        self.selectedLanguage = appState.appConfig.lang
    }

    // MARK: - Password Management

    func enablePassword() {
        guard !newPassword.isEmpty else {
            passwordError = L("preferences.password.empty")
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = L("preferences.password.mismatch")
            return
        }
        guard newPassword.count >= 4 else {
            passwordError = L("preferences.password.tooShort")
            return
        }
        appState.appConfig.password = hashPassword(newPassword)
        appState.saveAppConfig()
        isPasswordEnabled = true
        clearPasswordFields()
    }

    func disablePassword() {
        guard validatePassword(currentPassword) else {
            passwordError = L("preferences.password.incorrect")
            return
        }
        appState.appConfig.password = ""
        appState.saveAppConfig()
        appState.isPasswordVerified = true
        isPasswordEnabled = false
        clearPasswordFields()
    }

    func changePassword() {
        guard validatePassword(currentPassword) else {
            passwordError = L("preferences.password.incorrect")
            return
        }
        guard !newPassword.isEmpty else {
            passwordError = L("preferences.password.empty")
            return
        }
        guard newPassword == confirmPassword else {
            passwordError = L("preferences.password.mismatch")
            return
        }
        guard newPassword.count >= 4 else {
            passwordError = L("preferences.password.tooShort")
            return
        }
        appState.appConfig.password = hashPassword(newPassword)
        appState.saveAppConfig()
        isShowingChangePassword = false
        clearPasswordFields()
    }

    func validatePassword(_ password: String) -> Bool {
        let storedHash = appState.appConfig.password
        guard !storedHash.isEmpty else { return true }
        return hashPassword(password) == storedHash
    }

    // MARK: - Language

    func saveLanguage() {
        appState.appConfig.lang = selectedLanguage
        appState.saveAppConfig()
        
        // Save to UserDefaults for LanguageManager
        UserDefaults.standard.set(selectedLanguage, forKey: "savedLanguage")
        UserDefaults.standard.synchronize()
        
        // Update LanguageManager
        LanguageManager.shared.currentLanguage = selectedLanguage
        
        // Set AppleLanguages for next launch
        let languageMap: [String: String] = [
            "en": "en",
            "zh-Hans": "zh-Hans",
            "zh-Hant": "zh-Hant",
            "ja": "ja",
            "ko": "ko",
            "es": "es"
        ]
        
        if let appleLang = languageMap[selectedLanguage] {
            UserDefaults.standard.set([appleLang], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }

    // MARK: - Private Helpers

    private func clearPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        passwordError = nil
    }

    private func hashPassword(_ password: String) -> String {
        guard let data = password.data(using: .utf8) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
