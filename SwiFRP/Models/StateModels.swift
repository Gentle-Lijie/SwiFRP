import Foundation

enum ConfigState: String, Codable {
    case unknown
    case started
    case stopped
    case starting
    case stopping
}

enum ProxyState: String, Codable {
    case unknown
    case running
    case error
}

struct ProxyStatus: Codable, Identifiable {
    var id: String { name }
    var name: String
    var type: String
    var status: ProxyState
    var remoteAddr: String
    var error: String
}
