import XCTest
@testable import SwiFRP

final class ConfigParserTests: XCTestCase {

    // MARK: - TOML Parser

    func testTOMLParseBasic() {
        let toml = """
        serverAddr = "frp.example.com"
        serverPort = 7001
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["serverAddr"] as? String, "frp.example.com")
        XCTAssertEqual(dict["serverPort"] as? Int, 7001)
    }

    func testTOMLParseBoolean() {
        let toml = """
        enabled = true
        disabled = false
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["enabled"] as? Bool, true)
        XCTAssertEqual(dict["disabled"] as? Bool, false)
    }

    func testTOMLParseSection() {
        let toml = """
        [common]
        serverAddr = "example.com"
        serverPort = 7000
        """
        let dict = TOMLParser.parse(toml)
        let common = dict["common"] as? [String: Any]
        XCTAssertNotNil(common)
        XCTAssertEqual(common?["serverAddr"] as? String, "example.com")
        XCTAssertEqual(common?["serverPort"] as? Int, 7000)
    }

    func testTOMLParseWithProxies() {
        let toml = """
        serverAddr = "frp.example.com"
        serverPort = 7000

        [[proxies]]
        name = "ssh"
        type = "tcp"
        localPort = "22"
        remotePort = "6000"

        [[proxies]]
        name = "web"
        type = "http"
        localPort = "8080"
        subdomain = "myapp"
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["serverAddr"] as? String, "frp.example.com")

        let proxies = dict["proxies"] as? [[String: Any]]
        XCTAssertNotNil(proxies)
        XCTAssertEqual(proxies?.count, 2)
        XCTAssertEqual(proxies?[0]["name"] as? String, "ssh")
        XCTAssertEqual(proxies?[0]["type"] as? String, "tcp")
        XCTAssertEqual(proxies?[0]["localPort"] as? String, "22")
        XCTAssertEqual(proxies?[0]["remotePort"] as? String, "6000")
        XCTAssertEqual(proxies?[1]["name"] as? String, "web")
        XCTAssertEqual(proxies?[1]["type"] as? String, "http")
        XCTAssertEqual(proxies?[1]["subdomain"] as? String, "myapp")
    }

    func testTOMLParseArray() {
        let toml = """
        customDomains = ["example.com", "www.example.com"]
        """
        let dict = TOMLParser.parse(toml)
        let domains = dict["customDomains"] as? [String]
        XCTAssertEqual(domains, ["example.com", "www.example.com"])
    }

    func testTOMLParseEmptyArray() {
        let toml = """
        items = []
        """
        let dict = TOMLParser.parse(toml)
        let items = dict["items"] as? [String]
        XCTAssertNotNil(items)
        XCTAssertTrue(items?.isEmpty ?? false)
    }

    func testTOMLParseComments() {
        let toml = """
        # This is a comment
        serverAddr = "example.com"
        serverPort = 7000 # inline comment
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["serverAddr"] as? String, "example.com")
        XCTAssertEqual(dict["serverPort"] as? Int, 7000)
    }

    func testTOMLParseBareString() {
        let toml = """
        name = ssh
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["name"] as? String, "ssh")
    }

    func testTOMLParseSingleQuotedString() {
        let toml = """
        name = 'hello world'
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertEqual(dict["name"] as? String, "hello world")
    }

    func testTOMLSerialize() {
        let dict: [String: Any] = [
            "serverAddr": "example.com",
            "serverPort": 7000,
        ]
        let output = TOMLParser.serialize(dict)
        XCTAssertTrue(output.contains("serverAddr = \"example.com\""))
        XCTAssertTrue(output.contains("serverPort = 7000"))
    }

    func testTOMLSerializeWithSection() {
        let dict: [String: Any] = [
            "common": ["serverAddr": "example.com", "serverPort": 7000] as [String: Any],
        ]
        let output = TOMLParser.serialize(dict)
        XCTAssertTrue(output.contains("[common]"))
        XCTAssertTrue(output.contains("serverAddr = \"example.com\""))
        XCTAssertTrue(output.contains("serverPort = 7000"))
    }

    func testTOMLSerializeWithArrayOfTables() {
        let dict: [String: Any] = [
            "proxies": [
                ["name": "ssh", "type": "tcp"] as [String: Any],
                ["name": "web", "type": "http"] as [String: Any],
            ],
        ]
        let output = TOMLParser.serialize(dict)
        XCTAssertTrue(output.contains("[[proxies]]"))
        XCTAssertTrue(output.contains("name = \"ssh\""))
        XCTAssertTrue(output.contains("name = \"web\""))
    }

    func testTOMLSerializeRoundtrip() {
        let original: [String: Any] = [
            "serverAddr": "frp.example.com",
            "serverPort": 7001,
        ]
        let serialized = TOMLParser.serialize(original)
        let parsed = TOMLParser.parse(serialized)
        XCTAssertEqual(parsed["serverAddr"] as? String, "frp.example.com")
        XCTAssertEqual(parsed["serverPort"] as? Int, 7001)
    }

    func testTOMLSerializeBoolean() {
        let dict: [String: Any] = [
            "enabled": true,
            "disabled": false,
        ]
        let output = TOMLParser.serialize(dict)
        XCTAssertTrue(output.contains("disabled = false"))
        XCTAssertTrue(output.contains("enabled = true"))
    }

    func testTOMLSerializeStringArray() {
        let dict: [String: Any] = [
            "domains": ["a.com", "b.com"],
        ]
        let output = TOMLParser.serialize(dict)
        XCTAssertTrue(output.contains("[\"a.com\", \"b.com\"]"))
    }

    // MARK: - INI Parser

    func testINIParseBasic() {
        let ini = """
        [common]
        server_addr = 192.168.1.1
        server_port = 7000
        """
        let sections = INIParser.parse(ini)
        XCTAssertNotNil(sections["common"])
        XCTAssertEqual(sections["common"]?["server_addr"], "192.168.1.1")
        XCTAssertEqual(sections["common"]?["server_port"], "7000")
    }

    func testINIParseWithSections() {
        let ini = """
        [common]
        server_addr = example.com
        server_port = 7000

        [ssh]
        type = tcp
        local_port = 22
        remote_port = 6000

        [web]
        type = http
        local_port = 80
        subdomain = myapp
        """
        let sections = INIParser.parse(ini)
        XCTAssertEqual(sections.count, 3)

        XCTAssertEqual(sections["common"]?["server_addr"], "example.com")
        XCTAssertEqual(sections["ssh"]?["type"], "tcp")
        XCTAssertEqual(sections["ssh"]?["local_port"], "22")
        XCTAssertEqual(sections["ssh"]?["remote_port"], "6000")
        XCTAssertEqual(sections["web"]?["type"], "http")
        XCTAssertEqual(sections["web"]?["subdomain"], "myapp")
    }

    func testINIParseComments() {
        let ini = """
        # This is a comment
        ; This is also a comment
        [common]
        server_addr = example.com # inline comment
        server_port = 7000 ; another inline comment
        """
        let sections = INIParser.parse(ini)
        XCTAssertEqual(sections["common"]?["server_addr"], "example.com")
        XCTAssertEqual(sections["common"]?["server_port"], "7000")
    }

    func testINIParseEmptyLines() {
        let ini = """

        [common]

        server_addr = example.com

        server_port = 7000

        """
        let sections = INIParser.parse(ini)
        XCTAssertEqual(sections["common"]?["server_addr"], "example.com")
        XCTAssertEqual(sections["common"]?["server_port"], "7000")
    }

    func testINIParseKeysOutsideSection() {
        let ini = """
        key1 = value1
        key2 = value2
        [common]
        server_addr = example.com
        """
        let sections = INIParser.parse(ini)
        XCTAssertEqual(sections[""]?["key1"], "value1")
        XCTAssertEqual(sections[""]?["key2"], "value2")
        XCTAssertEqual(sections["common"]?["server_addr"], "example.com")
    }

    func testINISerialize() {
        let sections: [String: [String: String]] = [
            "common": ["server_addr": "example.com", "server_port": "7000"],
            "ssh": ["type": "tcp", "local_port": "22"],
        ]
        let output = INIParser.serialize(sections)
        XCTAssertTrue(output.contains("[common]"))
        XCTAssertTrue(output.contains("server_addr = example.com"))
        XCTAssertTrue(output.contains("server_port = 7000"))
        XCTAssertTrue(output.contains("[ssh]"))
        XCTAssertTrue(output.contains("type = tcp"))
        XCTAssertTrue(output.contains("local_port = 22"))
    }

    func testINISerializeCommonFirst() {
        let sections: [String: [String: String]] = [
            "ssh": ["type": "tcp"],
            "common": ["server_addr": "example.com"],
        ]
        let output = INIParser.serialize(sections)
        let commonIndex = output.range(of: "[common]")!.lowerBound
        let sshIndex = output.range(of: "[ssh]")!.lowerBound
        XCTAssertTrue(commonIndex < sshIndex, "[common] should appear before [ssh]")
    }

    func testINISerializeRoundtrip() {
        let original: [String: [String: String]] = [
            "common": ["server_addr": "example.com", "server_port": "7000"],
            "ssh": ["type": "tcp", "local_port": "22", "remote_port": "6000"],
        ]
        let serialized = INIParser.serialize(original)
        let parsed = INIParser.parse(serialized)
        XCTAssertEqual(parsed["common"]?["server_addr"], "example.com")
        XCTAssertEqual(parsed["common"]?["server_port"], "7000")
        XCTAssertEqual(parsed["ssh"]?["type"], "tcp")
        XCTAssertEqual(parsed["ssh"]?["local_port"], "22")
        XCTAssertEqual(parsed["ssh"]?["remote_port"], "6000")
    }

    // MARK: - ConfigConverter

    func testConfigConverterTOML() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "test")
        config.serverAddr = "frp.example.com"
        config.serverPort = 7001
        config.authMethod = "token"
        config.token = "mysecret"
        config.tlsEnable = true

        var proxy = ProxyConfig(name: "ssh")
        proxy.type = "tcp"
        proxy.localPort = "22"
        proxy.remotePort = "6000"
        config.proxies = [proxy]

        let toml = converter.configToTOML(config)
        XCTAssertFalse(toml.isEmpty)

        let restored = converter.tomlToConfig(toml, name: "test")
        XCTAssertEqual(restored.serverAddr, "frp.example.com")
        XCTAssertEqual(restored.serverPort, 7001)
        XCTAssertEqual(restored.authMethod, "token")
        XCTAssertEqual(restored.token, "mysecret")
        XCTAssertTrue(restored.tlsEnable)
        XCTAssertEqual(restored.proxies.count, 1)
        XCTAssertEqual(restored.proxies.first?.name, "ssh")
        XCTAssertEqual(restored.proxies.first?.type, "tcp")
        XCTAssertEqual(restored.proxies.first?.localPort, "22")
        XCTAssertEqual(restored.proxies.first?.remotePort, "6000")
    }

    func testConfigConverterINI() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "test")
        config.serverAddr = "frp.example.com"
        config.serverPort = 7001
        config.authMethod = "token"
        config.token = "mysecret"
        config.protocol = "kcp"

        var proxy = ProxyConfig(name: "ssh")
        proxy.type = "tcp"
        proxy.localPort = "22"
        proxy.remotePort = "6000"
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        XCTAssertFalse(ini.isEmpty)

        let restored = converter.iniToConfig(ini, name: "test")
        XCTAssertEqual(restored.serverAddr, "frp.example.com")
        XCTAssertEqual(restored.serverPort, 7001)
        XCTAssertEqual(restored.authMethod, "token")
        XCTAssertEqual(restored.token, "mysecret")
        XCTAssertEqual(restored.protocol, "kcp")
        XCTAssertTrue(restored.legacyFormat)
        XCTAssertEqual(restored.proxies.count, 1)
        XCTAssertEqual(restored.proxies.first?.name, "ssh")
        XCTAssertEqual(restored.proxies.first?.type, "tcp")
        XCTAssertEqual(restored.proxies.first?.localPort, "22")
        XCTAssertEqual(restored.proxies.first?.remotePort, "6000")
    }

    func testConfigConverterTOMLWithHttpProxy() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "web-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "web")
        proxy.type = "http"
        proxy.localPort = "8080"
        proxy.subdomain = "myapp"
        proxy.customDomains = ["example.com"]
        proxy.httpUser = "admin"
        proxy.httpPwd = "pass"
        config.proxies = [proxy]

        let toml = converter.configToTOML(config)
        let restored = converter.tomlToConfig(toml, name: "web-test")
        XCTAssertEqual(restored.proxies.count, 1)
        XCTAssertEqual(restored.proxies[0].type, "http")
        XCTAssertEqual(restored.proxies[0].subdomain, "myapp")
        XCTAssertEqual(restored.proxies[0].customDomains, ["example.com"])
        XCTAssertEqual(restored.proxies[0].httpUser, "admin")
        XCTAssertEqual(restored.proxies[0].httpPwd, "pass")
    }

    func testConfigConverterINIWithPlugin() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "plugin-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "file")
        proxy.type = "tcp"
        proxy.plugin.name = "static_file"
        proxy.plugin.localPath = "/var/www"
        proxy.plugin.stripPrefix = "/static"
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        let restored = converter.iniToConfig(ini, name: "plugin-test")
        XCTAssertEqual(restored.proxies.count, 1)
        XCTAssertEqual(restored.proxies[0].plugin.name, "static_file")
        XCTAssertEqual(restored.proxies[0].plugin.localPath, "/var/www")
        XCTAssertEqual(restored.proxies[0].plugin.stripPrefix, "/static")
    }

    func testConfigConverterINIWithBandwidth() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "bw-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "limited")
        proxy.type = "tcp"
        proxy.localPort = "22"
        proxy.remotePort = "6000"
        proxy.bandwidth.limit = 10
        proxy.bandwidth.unit = "MB"
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        XCTAssertTrue(ini.contains("bandwidth_limit = 10MB"))

        let restored = converter.iniToConfig(ini, name: "bw-test")
        XCTAssertEqual(restored.proxies[0].bandwidth.limit, 10)
        XCTAssertEqual(restored.proxies[0].bandwidth.unit, "MB")
    }

    func testConfigConverterINIWithLoadBalance() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "lb-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "web1")
        proxy.type = "http"
        proxy.localPort = "80"
        proxy.loadBalance.group = "web-group"
        proxy.loadBalance.groupKey = "secret"
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        let restored = converter.iniToConfig(ini, name: "lb-test")
        XCTAssertEqual(restored.proxies[0].loadBalance.group, "web-group")
        XCTAssertEqual(restored.proxies[0].loadBalance.groupKey, "secret")
    }

    func testConfigConverterINIWithHealthCheck() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "hc-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "web")
        proxy.type = "http"
        proxy.localPort = "80"
        proxy.healthCheck.type = "http"
        proxy.healthCheck.url = "/health"
        proxy.healthCheck.timeout = 3
        proxy.healthCheck.interval = 10
        proxy.healthCheck.maxFailed = 5
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        let restored = converter.iniToConfig(ini, name: "hc-test")
        XCTAssertEqual(restored.proxies[0].healthCheck.type, "http")
        XCTAssertEqual(restored.proxies[0].healthCheck.url, "/health")
        XCTAssertEqual(restored.proxies[0].healthCheck.timeout, 3)
        XCTAssertEqual(restored.proxies[0].healthCheck.interval, 10)
        XCTAssertEqual(restored.proxies[0].healthCheck.maxFailed, 5)
    }

    // MARK: - Format Detection

    func testDetectFormatTOML() {
        let converter = ConfigConverter()

        let toml = """
        serverAddr = "frp.example.com"
        serverPort = 7000

        [[proxies]]
        name = "ssh"
        type = "tcp"
        """
        XCTAssertEqual(converter.detectFormat(toml), .toml)
    }

    func testDetectFormatTOMLDottedKeys() {
        let converter = ConfigConverter()

        let toml = """
        transport.protocol = "tcp"
        transport.tls.enable = true
        """
        XCTAssertEqual(converter.detectFormat(toml), .toml)
    }

    func testDetectFormatINI() {
        let converter = ConfigConverter()

        let ini = """
        [common]
        server_addr = example.com
        server_port = 7000

        [ssh]
        type = tcp
        """
        XCTAssertEqual(converter.detectFormat(ini), .ini)
    }

    func testDetectFormatDefaultsToTOML() {
        let converter = ConfigConverter()
        let ambiguous = """
        some_key = some_value
        """
        // Without clear indicators, defaults to TOML
        XCTAssertEqual(converter.detectFormat(ambiguous), .toml)
    }

    // MARK: - ConfigFormat

    func testConfigFormatCases() {
        XCTAssertEqual(ConfigFormat.allCases.count, 2)
        XCTAssertEqual(ConfigFormat.toml.rawValue, "toml")
        XCTAssertEqual(ConfigFormat.ini.rawValue, "ini")
    }

    // MARK: - TOML ClientConfig Conversion

    func testTOMLClientConfigToDict() {
        var config = ClientConfig(name: "test")
        config.serverAddr = "example.com"
        config.serverPort = 7001
        config.logLevel = "debug"

        let dict = TOMLParser.clientConfigToDict(config)
        let common = dict["common"] as? [String: Any]
        XCTAssertNotNil(common)
        XCTAssertEqual(common?["serverAddr"] as? String, "example.com")
        XCTAssertEqual(common?["serverPort"] as? Int, 7001)
        XCTAssertEqual(common?["log.level"] as? String, "debug")
    }

    func testTOMLDictToClientConfig() {
        let dict: [String: Any] = [
            "common": [
                "serverAddr": "example.com",
                "serverPort": 7001,
                "transport.protocol": "kcp",
                "transport.tls.enable": true,
            ] as [String: Any],
            "proxies": [
                ["name": "ssh", "type": "tcp", "localPort": "22", "remotePort": "6000"] as [String: Any],
            ],
        ]
        let config = TOMLParser.dictToClientConfig(dict, name: "test")
        XCTAssertEqual(config.name, "test")
        XCTAssertEqual(config.serverAddr, "example.com")
        XCTAssertEqual(config.serverPort, 7001)
        XCTAssertEqual(config.protocol, "kcp")
        XCTAssertTrue(config.tlsEnable)
        XCTAssertEqual(config.proxies.count, 1)
        XCTAssertEqual(config.proxies[0].name, "ssh")
    }

    func testTOMLProxyConfigToDict() {
        var proxy = ProxyConfig(name: "ssh")
        proxy.type = "tcp"
        proxy.localPort = "22"
        proxy.remotePort = "6000"
        proxy.useEncryption = true

        let dict = TOMLParser.proxyConfigToDict(proxy)
        XCTAssertEqual(dict["name"] as? String, "ssh")
        XCTAssertEqual(dict["type"] as? String, "tcp")
        XCTAssertEqual(dict["localPort"] as? String, "22")
        XCTAssertEqual(dict["remotePort"] as? String, "6000")
        XCTAssertEqual(dict["transport.useEncryption"] as? Bool, true)
    }

    func testTOMLDictToProxyConfig() {
        let dict: [String: Any] = [
            "name": "web",
            "type": "http",
            "localPort": "8080",
            "subdomain": "myapp",
            "customDomains": ["a.com", "b.com"],
            "httpUser": "admin",
            "httpPassword": "pass",
            "transport.useCompression": true,
        ]
        let proxy = TOMLParser.dictToProxyConfig(dict)
        XCTAssertEqual(proxy.name, "web")
        XCTAssertEqual(proxy.type, "http")
        XCTAssertEqual(proxy.localPort, "8080")
        XCTAssertEqual(proxy.subdomain, "myapp")
        XCTAssertEqual(proxy.customDomains, ["a.com", "b.com"])
        XCTAssertEqual(proxy.httpUser, "admin")
        XCTAssertEqual(proxy.httpPwd, "pass")
        XCTAssertTrue(proxy.useCompression)
    }

    // MARK: - Edge Cases

    func testTOMLParseEmpty() {
        let dict = TOMLParser.parse("")
        XCTAssertTrue(dict.isEmpty)
    }

    func testINIParseEmpty() {
        let sections = INIParser.parse("")
        XCTAssertTrue(sections.isEmpty)
    }

    func testTOMLParseOnlyComments() {
        let toml = """
        # This is a comment
        # Another comment
        """
        let dict = TOMLParser.parse(toml)
        XCTAssertTrue(dict.isEmpty)
    }

    func testINIParseOnlyComments() {
        let ini = """
        # This is a comment
        ; Another comment
        """
        let sections = INIParser.parse(ini)
        XCTAssertTrue(sections.isEmpty)
    }

    func testConfigConverterDefaultValues() {
        let converter = ConfigConverter()
        let config = ClientConfig(name: "defaults")

        // A default config should serialize to minimal output
        let toml = converter.configToTOML(config)
        XCTAssertFalse(toml.isEmpty)

        let restored = converter.tomlToConfig(toml, name: "defaults")
        XCTAssertEqual(restored.serverPort, 7000)
        XCTAssertEqual(restored.logLevel, "info")
        XCTAssertEqual(restored.logMaxDays, 3)
        XCTAssertEqual(restored.protocol, "tcp")
    }

    func testConfigConverterINIEncryptionCompression() {
        let converter = ConfigConverter()
        var config = ClientConfig(name: "enc-test")
        config.serverAddr = "example.com"

        var proxy = ProxyConfig(name: "secure")
        proxy.type = "tcp"
        proxy.localPort = "22"
        proxy.remotePort = "6000"
        proxy.useEncryption = true
        proxy.useCompression = true
        config.proxies = [proxy]

        let ini = converter.configToINI(config)
        let restored = converter.iniToConfig(ini, name: "enc-test")
        XCTAssertTrue(restored.proxies[0].useEncryption)
        XCTAssertTrue(restored.proxies[0].useCompression)
    }

    func testConfigConverterTOMLWithP2PProxy() {
        let converter = ConfigConverter()

        var config = ClientConfig(name: "p2p-test")
        config.serverAddr = "frp.example.com"

        var proxy = ProxyConfig(name: "p2p-ssh")
        proxy.type = "xtcp"
        proxy.localPort = "22"
        proxy.secretKey = "my-secret"
        proxy.role = "visitor"
        config.proxies = [proxy]

        let toml = converter.configToTOML(config)
        let restored = converter.tomlToConfig(toml, name: "p2p-test")
        XCTAssertEqual(restored.proxies.count, 1)
        XCTAssertEqual(restored.proxies[0].type, "xtcp")
        XCTAssertEqual(restored.proxies[0].secretKey, "my-secret")
        XCTAssertEqual(restored.proxies[0].role, "visitor")
    }
}
