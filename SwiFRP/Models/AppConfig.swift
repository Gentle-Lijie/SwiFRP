import Foundation

struct AppConfig: Codable {
    var password: String = ""
    var sort: [String] = []
    var autoStart: Bool = false
    var language: String = "en"
}
