import Foundation

struct ClientConfig: Codable, Identifiable {
    var id: String { name }
    var name: String
    var serverAddr: String = ""
    var serverPort: Int = 7000
    var token: String = ""
    var content: String = ""
}
