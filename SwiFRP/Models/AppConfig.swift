import Foundation

/// Application-level configuration stored in app.json
struct AppConfig: Codable {
    var lang: String = "en"
    var password: String = ""
    var checkUpdate: Bool = true
    var defaults: DefaultConfig = DefaultConfig()
    var sort: [String] = []
    var position: [Double] = [100, 200, 800, 600]
}

struct DefaultConfig: Codable {
    var `protocol`: String = "tcp"
    var user: String = ""
    var logLevel: String = "info"
    var logMaxDays: Int = 3
    var dnsServer: String = ""
    var natHoleSTUNServer: String = "stun.easyvoip.com:3478"
    var connectServerLocalIP: String = ""
    var tcpMux: Bool = true
    var tlsEnable: Bool = true
    var manualStart: Bool = false
    var legacyFormat: Bool = false
}
