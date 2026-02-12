import Foundation

struct ProxyConfig: Codable, Identifiable, Equatable {
    var id: String { name }

    // MARK: - Basic
    var name: String
    var type: String = "tcp"
    var disabled: Bool = false

    // MARK: - Local
    var localIP: String = "127.0.0.1"
    var localPort: Int? = nil
    var remotePort: Int? = nil

    // MARK: - Peer-to-peer (xtcp/stcp/sudp)
    var role: String = "server"
    var secretKey: String = ""
    var allowUsers: [String] = []
    var bindAddr: String = ""
    var bindPort: Int = 0
    var serverName: String = ""
    var serverUser: String = ""

    // MARK: - Domain-based (http/https/tcpmux)
    var subdomain: String = ""
    var customDomains: [String] = []
    var locations: [String] = []
    var multiplexer: String = ""
    var routeByHTTPUser: String = ""

    // MARK: - Bandwidth
    var bandwidth: BandwidthConfig = BandwidthConfig()

    // MARK: - Advanced
    var proxyProtocolVersion: String = ""
    var transport: String = ""
    var keepTunnel: Bool = false
    var useEncryption: Bool = false
    var useCompression: Bool = false
    var http2: Bool = false
    var disableAuxAddress: Bool = false
    var fallbackTo: String = ""
    var fallbackTimeout: Int = 0
    var maxRetriesPerHour: Int = 0
    var minRetryInterval: Int = 0

    // MARK: - HTTP
    var httpUser: String = ""
    var httpPwd: String = ""
    var hostHeaderRewrite: String = ""
    var requestHeaders: [String: String] = [:]
    var responseHeaders: [String: String] = [:]

    // MARK: - Plugin
    var plugin: PluginConfig = PluginConfig()

    // MARK: - Load Balance
    var loadBalance: LoadBalanceConfig = LoadBalanceConfig()

    // MARK: - Health Check
    var healthCheck: HealthCheckConfig = HealthCheckConfig()

    // MARK: - Metadata & Annotations
    var metadatas: [String: String] = [:]
    var annotations: [String: String] = [:]
}

// MARK: - BandwidthConfig

struct BandwidthConfig: Codable, Equatable {
    var limit: Int = 0
    var unit: String = "MB"
    var mode: String = "client"
}

// MARK: - PluginConfig

struct PluginConfig: Codable, Equatable {
    var name: String = ""

    // http2http, http2https, https2http, https2https, tls2raw
    var localAddr: String = ""
    var hostHeaderRewrite: String = ""
    var requestHeaders: [String: String] = [:]

    // https2http, https2https, tls2raw
    var tlsCertFile: String = ""
    var tlsKeyFile: String = ""

    // tls2raw
    var tlsTrustedCaFile: String = ""

    // http_proxy
    var httpUser: String = ""
    var httpPwd: String = ""

    // socks5
    var socks5User: String = ""
    var socks5Pwd: String = ""

    // static_file
    var localPath: String = ""
    var stripPrefix: String = ""
    var staticFileUser: String = ""
    var staticFilePwd: String = ""

    // unix_domain_socket
    var unixPath: String = ""
}

// MARK: - LoadBalanceConfig

struct LoadBalanceConfig: Codable, Equatable {
    var group: String = ""
    var groupKey: String = ""
}

// MARK: - HealthCheckConfig

struct HealthCheckConfig: Codable, Equatable {
    var type: String = ""
    var url: String = ""
    var timeout: Int = 0
    var interval: Int = 0
    var maxFailed: Int = 0
}
