import XCTest
@testable import SwiFRP

final class ModelTests: XCTestCase {

    // MARK: - AppConfig

    func testAppConfigDefaults() {
        let config = AppConfig()
        XCTAssertEqual(config.lang, "en")
        XCTAssertEqual(config.password, "")
        XCTAssertTrue(config.checkUpdate)
        XCTAssertTrue(config.sort.isEmpty)
        XCTAssertEqual(config.position, [100, 200, 800, 600])
        XCTAssertEqual(config.defaults.protocol, "tcp")
        XCTAssertEqual(config.defaults.logLevel, "info")
        XCTAssertEqual(config.defaults.logMaxDays, 3)
        XCTAssertTrue(config.defaults.tcpMux)
        XCTAssertTrue(config.defaults.tlsEnable)
        XCTAssertFalse(config.defaults.manualStart)
        XCTAssertFalse(config.defaults.legacyFormat)
    }

    func testAppConfigCodable() throws {
        var config = AppConfig()
        config.lang = "zh-Hans"
        config.password = "test"
        config.checkUpdate = false
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
        XCTAssertEqual(decoded.lang, "zh-Hans")
        XCTAssertEqual(decoded.password, "test")
        XCTAssertFalse(decoded.checkUpdate)
    }

    func testDefaultConfigDefaults() {
        let dc = DefaultConfig()
        XCTAssertEqual(dc.protocol, "tcp")
        XCTAssertEqual(dc.user, "")
        XCTAssertEqual(dc.logLevel, "info")
        XCTAssertEqual(dc.logMaxDays, 3)
        XCTAssertEqual(dc.dnsServer, "")
        XCTAssertEqual(dc.natHoleSTUNServer, "stun.easyvoip.com:3478")
        XCTAssertEqual(dc.connectServerLocalIP, "")
        XCTAssertTrue(dc.tcpMux)
        XCTAssertTrue(dc.tlsEnable)
        XCTAssertFalse(dc.manualStart)
        XCTAssertFalse(dc.legacyFormat)
    }

    func testDefaultConfigCodable() throws {
        var dc = DefaultConfig()
        dc.protocol = "kcp"
        dc.logLevel = "debug"
        dc.tcpMux = false
        let data = try JSONEncoder().encode(dc)
        let decoded = try JSONDecoder().decode(DefaultConfig.self, from: data)
        XCTAssertEqual(decoded.protocol, "kcp")
        XCTAssertEqual(decoded.logLevel, "debug")
        XCTAssertFalse(decoded.tcpMux)
    }

    // MARK: - ClientConfig

    func testClientConfigDefaults() {
        let config = ClientConfig(name: "test")
        XCTAssertEqual(config.name, "test")
        XCTAssertEqual(config.id, "test")
        XCTAssertEqual(config.serverPort, 7000)
        XCTAssertEqual(config.serverAddr, "")
        XCTAssertEqual(config.user, "")
        XCTAssertEqual(config.protocol, "tcp")
        XCTAssertEqual(config.logLevel, "info")
        XCTAssertEqual(config.logMaxDays, 3)
        XCTAssertTrue(config.tlsEnable)
        XCTAssertTrue(config.tcpMux)
        XCTAssertTrue(config.loginFailExit)
        XCTAssertEqual(config.heartbeatInterval, 30)
        XCTAssertEqual(config.heartbeatTimeout, 90)
        XCTAssertEqual(config.dialTimeout, 10)
        XCTAssertEqual(config.keepalivePeriod, 30)
        XCTAssertFalse(config.manualStart)
        XCTAssertFalse(config.legacyFormat)
        XCTAssertTrue(config.proxies.isEmpty)
    }

    func testClientConfigCodable() throws {
        var config = ClientConfig(name: "myserver")
        config.serverAddr = "frp.example.com"
        config.serverPort = 7001
        config.authMethod = "token"
        config.token = "secret123"
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ClientConfig.self, from: data)
        XCTAssertEqual(decoded.name, "myserver")
        XCTAssertEqual(decoded.serverAddr, "frp.example.com")
        XCTAssertEqual(decoded.serverPort, 7001)
        XCTAssertEqual(decoded.authMethod, "token")
        XCTAssertEqual(decoded.token, "secret123")
    }

    func testClientConfigIdentifiable() {
        let config = ClientConfig(name: "myconfig")
        XCTAssertEqual(config.id, config.name)
    }

    func testClientConfigAuthFields() throws {
        var config = ClientConfig(name: "oidc-test")
        config.authMethod = "oidc"
        config.oidcClientID = "my-client"
        config.oidcClientSecret = "my-secret"
        config.oidcAudience = "api"
        config.oidcScope = "openid"
        config.oidcTokenEndpoint = "https://auth.example.com/token"
        config.authHeartbeat = true
        config.authNewWorkConn = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ClientConfig.self, from: data)
        XCTAssertEqual(decoded.authMethod, "oidc")
        XCTAssertEqual(decoded.oidcClientID, "my-client")
        XCTAssertEqual(decoded.oidcClientSecret, "my-secret")
        XCTAssertEqual(decoded.oidcAudience, "api")
        XCTAssertEqual(decoded.oidcScope, "openid")
        XCTAssertEqual(decoded.oidcTokenEndpoint, "https://auth.example.com/token")
        XCTAssertTrue(decoded.authHeartbeat)
        XCTAssertTrue(decoded.authNewWorkConn)
    }

    func testClientConfigAdminFields() throws {
        var config = ClientConfig(name: "admin-test")
        config.adminAddr = "127.0.0.1"
        config.adminPort = 7400
        config.adminUser = "admin"
        config.adminPwd = "pass"
        config.adminTLS = true
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ClientConfig.self, from: data)
        XCTAssertEqual(decoded.adminAddr, "127.0.0.1")
        XCTAssertEqual(decoded.adminPort, 7400)
        XCTAssertEqual(decoded.adminUser, "admin")
        XCTAssertEqual(decoded.adminPwd, "pass")
        XCTAssertTrue(decoded.adminTLS)
    }

    // MARK: - ProxyConfig

    func testProxyConfigDefaults() {
        let proxy = ProxyConfig(name: "ssh")
        XCTAssertEqual(proxy.name, "ssh")
        XCTAssertEqual(proxy.type, "tcp")
        XCTAssertFalse(proxy.disabled)
        XCTAssertEqual(proxy.localIP, "127.0.0.1")
        XCTAssertNil(proxy.localPort)
        XCTAssertNil(proxy.remotePort)
        XCTAssertEqual(proxy.role, "server")
        XCTAssertEqual(proxy.secretKey, "")
        XCTAssertTrue(proxy.customDomains.isEmpty)
        XCTAssertFalse(proxy.useEncryption)
        XCTAssertFalse(proxy.useCompression)
    }

    func testProxyConfigCodable() throws {
        var proxy = ProxyConfig(name: "web")
        proxy.type = "http"
        proxy.subdomain = "myapp"
        proxy.customDomains = ["example.com", "www.example.com"]
        proxy.localPort = 8080
        let data = try JSONEncoder().encode(proxy)
        let decoded = try JSONDecoder().decode(ProxyConfig.self, from: data)
        XCTAssertEqual(decoded.name, "web")
        XCTAssertEqual(decoded.type, "http")
        XCTAssertEqual(decoded.subdomain, "myapp")
        XCTAssertEqual(decoded.customDomains, ["example.com", "www.example.com"])
        XCTAssertEqual(decoded.localPort, 8080)
    }

    func testProxyConfigIdentifiable() {
        let proxy = ProxyConfig(name: "my-proxy")
        XCTAssertEqual(proxy.id, "my-proxy")
    }

    func testProxyConfigWithPlugin() throws {
        var proxy = ProxyConfig(name: "file-server")
        proxy.type = "tcp"
        proxy.plugin.name = "static_file"
        proxy.plugin.localPath = "/var/www"
        proxy.plugin.stripPrefix = "/static"
        let data = try JSONEncoder().encode(proxy)
        let decoded = try JSONDecoder().decode(ProxyConfig.self, from: data)
        XCTAssertEqual(decoded.plugin.name, "static_file")
        XCTAssertEqual(decoded.plugin.localPath, "/var/www")
        XCTAssertEqual(decoded.plugin.stripPrefix, "/static")
    }

    func testProxyConfigWithHealthCheck() throws {
        var proxy = ProxyConfig(name: "web-hc")
        proxy.type = "http"
        proxy.healthCheck.type = "http"
        proxy.healthCheck.url = "/health"
        proxy.healthCheck.timeout = 3
        proxy.healthCheck.interval = 10
        proxy.healthCheck.maxFailed = 5
        let data = try JSONEncoder().encode(proxy)
        let decoded = try JSONDecoder().decode(ProxyConfig.self, from: data)
        XCTAssertEqual(decoded.healthCheck.type, "http")
        XCTAssertEqual(decoded.healthCheck.url, "/health")
        XCTAssertEqual(decoded.healthCheck.timeout, 3)
        XCTAssertEqual(decoded.healthCheck.interval, 10)
        XCTAssertEqual(decoded.healthCheck.maxFailed, 5)
    }

    func testProxyConfigWithLoadBalance() throws {
        var proxy = ProxyConfig(name: "web-lb")
        proxy.loadBalance.group = "web-group"
        proxy.loadBalance.groupKey = "secret"
        let data = try JSONEncoder().encode(proxy)
        let decoded = try JSONDecoder().decode(ProxyConfig.self, from: data)
        XCTAssertEqual(decoded.loadBalance.group, "web-group")
        XCTAssertEqual(decoded.loadBalance.groupKey, "secret")
    }

    // MARK: - BandwidthConfig

    func testBandwidthConfigDefaults() {
        let bw = BandwidthConfig()
        XCTAssertEqual(bw.limit, 0)
        XCTAssertEqual(bw.unit, "MB")
        XCTAssertEqual(bw.mode, "client")
    }

    func testBandwidthConfigCodable() throws {
        var bw = BandwidthConfig()
        bw.limit = 100
        bw.unit = "KB"
        bw.mode = "server"
        let data = try JSONEncoder().encode(bw)
        let decoded = try JSONDecoder().decode(BandwidthConfig.self, from: data)
        XCTAssertEqual(decoded.limit, 100)
        XCTAssertEqual(decoded.unit, "KB")
        XCTAssertEqual(decoded.mode, "server")
    }

    // MARK: - PluginConfig

    func testPluginConfigDefaults() {
        let pc = PluginConfig()
        XCTAssertEqual(pc.name, "")
        XCTAssertEqual(pc.localAddr, "")
        XCTAssertEqual(pc.httpUser, "")
        XCTAssertEqual(pc.httpPwd, "")
        XCTAssertEqual(pc.localPath, "")
        XCTAssertEqual(pc.stripPrefix, "")
        XCTAssertEqual(pc.unixPath, "")
    }

    // MARK: - LoadBalanceConfig

    func testLoadBalanceConfigDefaults() {
        let lb = LoadBalanceConfig()
        XCTAssertEqual(lb.group, "")
        XCTAssertEqual(lb.groupKey, "")
    }

    // MARK: - HealthCheckConfig

    func testHealthCheckConfigDefaults() {
        let hc = HealthCheckConfig()
        XCTAssertEqual(hc.type, "")
        XCTAssertEqual(hc.url, "")
        XCTAssertEqual(hc.timeout, 0)
        XCTAssertEqual(hc.interval, 0)
        XCTAssertEqual(hc.maxFailed, 0)
    }

    // MARK: - AutoDelete

    func testAutoDeleteDefaults() {
        let ad = AutoDelete()
        XCTAssertEqual(ad.deleteMethod, .none)
        XCTAssertEqual(ad.deleteAfterDays, 0)
    }

    func testDeleteMethodCases() {
        XCTAssertEqual(DeleteMethod.allCases.count, 3)
        XCTAssertEqual(DeleteMethod.none.rawValue, "none")
        XCTAssertEqual(DeleteMethod.absolute.rawValue, "absolute")
        XCTAssertEqual(DeleteMethod.relative.rawValue, "relative")
    }

    func testAutoDeleteCodable() throws {
        var ad = AutoDelete()
        ad.deleteMethod = .absolute
        ad.deleteAfterDays = 7
        let data = try JSONEncoder().encode(ad)
        let decoded = try JSONDecoder().decode(AutoDelete.self, from: data)
        XCTAssertEqual(decoded.deleteMethod, .absolute)
        XCTAssertEqual(decoded.deleteAfterDays, 7)
    }

    // MARK: - StateModels

    func testConfigState() {
        XCTAssertEqual(ConfigState.started.rawValue, "started")
        XCTAssertEqual(ConfigState.stopped.rawValue, "stopped")
        XCTAssertEqual(ConfigState.starting.rawValue, "starting")
        XCTAssertEqual(ConfigState.stopping.rawValue, "stopping")
        XCTAssertEqual(ConfigState.unknown.rawValue, "unknown")
    }

    func testProxyState() {
        XCTAssertEqual(ProxyState.unknown.rawValue, "unknown")
        XCTAssertEqual(ProxyState.running.rawValue, "running")
        XCTAssertEqual(ProxyState.error.rawValue, "error")
    }

    func testProxyStatus() {
        let status = ProxyStatus(name: "ssh", type: "tcp", status: .running, remoteAddr: ":6000", error: "")
        XCTAssertEqual(status.id, "ssh")
        XCTAssertEqual(status.name, "ssh")
        XCTAssertEqual(status.type, "tcp")
        XCTAssertEqual(status.status, .running)
        XCTAssertEqual(status.remoteAddr, ":6000")
        XCTAssertEqual(status.error, "")
    }

    func testProxyStatusCodable() throws {
        let status = ProxyStatus(name: "web", type: "http", status: .error, remoteAddr: "", error: "port conflict")
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(ProxyStatus.self, from: data)
        XCTAssertEqual(decoded.name, "web")
        XCTAssertEqual(decoded.type, "http")
        XCTAssertEqual(decoded.status, .error)
        XCTAssertEqual(decoded.error, "port conflict")
    }

    // MARK: - Constants

    func testConstants() {
        XCTAssertFalse(Constants.appVersion.isEmpty)
        XCTAssertFalse(Constants.frpVersion.isEmpty)
        XCTAssertFalse(Constants.buildDate.isEmpty)
    }

    func testConstantsProtocols() {
        XCTAssertTrue(Constants.protocols.contains("tcp"))
        XCTAssertTrue(Constants.protocols.contains("kcp"))
        XCTAssertTrue(Constants.protocols.contains("quic"))
        XCTAssertTrue(Constants.protocols.contains("websocket"))
        XCTAssertTrue(Constants.protocols.contains("wss"))
        XCTAssertEqual(Constants.protocols.count, 5)
    }

    func testConstantsProxyTypes() {
        XCTAssertEqual(Constants.proxyTypes.count, 8)
        XCTAssertTrue(Constants.proxyTypes.contains("tcp"))
        XCTAssertTrue(Constants.proxyTypes.contains("udp"))
        XCTAssertTrue(Constants.proxyTypes.contains("http"))
        XCTAssertTrue(Constants.proxyTypes.contains("https"))
        XCTAssertTrue(Constants.proxyTypes.contains("xtcp"))
        XCTAssertTrue(Constants.proxyTypes.contains("stcp"))
        XCTAssertTrue(Constants.proxyTypes.contains("sudp"))
        XCTAssertTrue(Constants.proxyTypes.contains("tcpmux"))
    }

    func testConstantsPluginTypes() {
        XCTAssertEqual(Constants.pluginTypes.count, 9)
        XCTAssertTrue(Constants.pluginTypes.contains("http2http"))
        XCTAssertTrue(Constants.pluginTypes.contains("socks5"))
        XCTAssertTrue(Constants.pluginTypes.contains("static_file"))
        XCTAssertTrue(Constants.pluginTypes.contains("tls2raw"))
    }

    func testConstantsDefaults() {
        XCTAssertEqual(Constants.defaultServerPort, 7000)
        XCTAssertEqual(Constants.defaultSTUNServer, "stun.easyvoip.com:3478")
        XCTAssertEqual(Constants.authMethods, ["token", "oidc"])
        XCTAssertEqual(Constants.logLevels, ["trace", "debug", "info", "warn", "error"])
    }

    // MARK: - AppPaths

    func testAppPathsConfigURL() {
        let tomlURL = AppPaths.configURL(for: "test", legacyFormat: false)
        XCTAssertTrue(tomlURL.lastPathComponent.hasSuffix(".toml"))
        XCTAssertEqual(tomlURL.lastPathComponent, "test.toml")

        let iniURL = AppPaths.configURL(for: "test", legacyFormat: true)
        XCTAssertTrue(iniURL.lastPathComponent.hasSuffix(".ini"))
        XCTAssertEqual(iniURL.lastPathComponent, "test.ini")
    }

    func testAppPathsLogURL() {
        let logURL = AppPaths.logURL(for: "myconfig")
        XCTAssertEqual(logURL.lastPathComponent, "myconfig.log")
    }

    func testAppPathsDirectoryStructure() {
        let support = AppPaths.appSupportDirectory
        XCTAssertTrue(support.path.contains("SwiFRP"))

        let configDir = AppPaths.configDirectory
        XCTAssertTrue(configDir.path.contains("configs"))

        let logsDir = AppPaths.logsDirectory
        XCTAssertTrue(logsDir.path.contains("logs"))
    }

    // MARK: - AppTab

    func testAppTabCases() {
        XCTAssertEqual(AppTab.allCases.count, 4)
        XCTAssertEqual(AppTab.configuration.rawValue, "configuration")
        XCTAssertEqual(AppTab.log.rawValue, "log")
        XCTAssertEqual(AppTab.preferences.rawValue, "preferences")
        XCTAssertEqual(AppTab.about.rawValue, "about")
    }

    // MARK: - ClientConfig with Proxies

    func testClientConfigWithProxiesCodable() throws {
        var config = ClientConfig(name: "full-test")
        config.serverAddr = "frp.example.com"
        config.serverPort = 7000

        var proxy1 = ProxyConfig(name: "ssh")
        proxy1.type = "tcp"
        proxy1.localPort = 22
        proxy1.remotePort = 6000

        var proxy2 = ProxyConfig(name: "web")
        proxy2.type = "http"
        proxy2.localPort = 80
        proxy2.subdomain = "myapp"

        config.proxies = [proxy1, proxy2]

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ClientConfig.self, from: data)
        XCTAssertEqual(decoded.proxies.count, 2)
        XCTAssertEqual(decoded.proxies[0].name, "ssh")
        XCTAssertEqual(decoded.proxies[0].remotePort, 6000)
        XCTAssertEqual(decoded.proxies[1].name, "web")
        XCTAssertEqual(decoded.proxies[1].subdomain, "myapp")
    }
}
