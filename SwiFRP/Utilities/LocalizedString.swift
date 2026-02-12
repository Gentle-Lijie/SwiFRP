import Foundation

/// Language manager for dynamic language switching
class LanguageManager {
    static let shared = LanguageManager()
    
    var currentLanguage: String {
        didSet {
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            _bundle = nil
        }
    }
    
    private var _bundle: Bundle?
    
    private var bundle: Bundle {
        if let bundle = _bundle {
            return bundle
        }
        
        // Try to find the .lproj directory for current language
        let languageMap: [String: String] = [
            "en": "en",
            "zh-Hans": "zh-Hans",
            "zh-Hant": "zh-Hant",
            "ja": "ja",
            "ko": "ko",
            "es": "es"
        ]
        
        let langCode = languageMap[currentLanguage] ?? currentLanguage
        
        // Check in main bundle (for packaged .app)
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            _bundle = bundle
            return bundle
        }
        
        // Try Bundle.module for SPM development environment (with availability check)
        #if SWIFT_PACKAGE
        if let path = Bundle.module.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            _bundle = bundle
            return bundle
        }
        // Fallback to module bundle in development
        _bundle = Bundle.module
        return Bundle.module
        #else
        // Fallback to main bundle for packaged app
        _bundle = Bundle.main
        return Bundle.main
        #endif
    }
    
    private init() {
        // Load saved language or use system language
        if let savedLang = UserDefaults.standard.string(forKey: "savedLanguage"),
           !savedLang.isEmpty {
            self.currentLanguage = savedLang
        } else if let appleLangs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String],
                  let firstLang = appleLangs.first {
            // Parse language code (e.g., "zh-Hans-CN" -> "zh-Hans")
            let parts = firstLang.split(separator: "-")
            if parts.count >= 2 {
                self.currentLanguage = "\(parts[0])-\(parts[1])"
            } else {
                self.currentLanguage = String(parts[0])
            }
        } else {
            self.currentLanguage = "en"
        }
    }
    
    func localizedString(for key: String) -> String {
        return NSLocalizedString(key, bundle: bundle, comment: "")
    }
    
    func localizedString(for key: String, args: CVarArg...) -> String {
        String(format: localizedString(for: key), arguments: args)
    }
}

/// Get localized string from module bundle
func L(_ key: String) -> String {
    return LanguageManager.shared.localizedString(for: key)
}

/// Get localized string with format arguments
func L(_ key: String, _ args: CVarArg...) -> String {
    return LanguageManager.shared.localizedString(for: key, args: args)
}
