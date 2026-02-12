import Foundation

struct ClientConfig: Codable, Identifiable, Equatable {
    var id: String { name }

    // MARK: - Basic
    var name: String
    var serverAddr: String = ""
    var serverPort: Int = 7000
    var user: String = ""
    var natHoleSTUNServer: String = ""

    // MARK: - Auth
    var authMethod: String = ""
    var token: String = ""
    var tokenFile: String = ""
    var oidcClientID: String = ""
    var oidcClientSecret: String = ""
    var oidcAudience: String = ""
    var oidcScope: String = ""
    var oidcTokenEndpoint: String = ""
    var oidcTokenEndpointParams: [String: String] = [:]
    var oidcProxyURL: String = ""
    var oidcTLSCA: String = ""
    var oidcSkipVerify: Bool = false
    var authHeartbeat: Bool = false
    var authNewWorkConn: Bool = false

    // MARK: - Log
    var logLevel: String = "info"
    var logMaxDays: Int = 3

    // MARK: - Admin
    var adminAddr: String = ""
    var adminPort: Int = 0
    var adminTLS: Bool = false
    var adminTLSCertFile: String = ""
    var adminTLSKeyFile: String = ""
    var adminUser: String = ""
    var adminPwd: String = ""
    var assetsDir: String = ""

    // MARK: - AutoDelete
    var autoDelete: AutoDelete = AutoDelete()

    // MARK: - Connection
    var `protocol`: String = "tcp"
    var dialTimeout: Int = 10
    var keepalivePeriod: Int = 30
    var connectPoolSize: Int = 0
    var quicKeepalivePeriod: Int = 10
    var quicMaxIdleTimeout: Int = 30
    var quicMaxIncomingStreams: Int = 0
    var heartbeatInterval: Int = 30
    var heartbeatTimeout: Int = 90

    // MARK: - TLS
    var tlsEnable: Bool = true
    var tlsServerName: String = ""
    var tlsCertFile: String = ""
    var tlsKeyFile: String = ""
    var tlsTrustedCaFile: String = ""
    var tlsDisableCustomFirstByte: Bool = false

    // MARK: - Advanced
    var dnsServer: String = ""
    var connectServerLocalIP: String = ""
    var tcpMux: Bool = true
    var tcpMuxKeepAliveInterval: Int = 60
    var loginFailExit: Bool = true
    var manualStart: Bool = false
    var legacyFormat: Bool = false
    var metadatas: [String: String] = [:]

    // MARK: - Proxies
    var proxies: [ProxyConfig] = []
}
