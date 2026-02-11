import Foundation

/// Supported FRP configuration file formats.
enum ConfigFormat: String, CaseIterable {
    case toml
    case ini
}

/// Converts between ClientConfig models and raw configuration content in TOML or INI format.
struct ConfigConverter {

    // MARK: - Config to Content

    /// Generates TOML content from a ClientConfig.
    func configToTOML(_ config: ClientConfig) -> String {
        let dict = TOMLParser.clientConfigToDict(config)
        return TOMLParser.serialize(dict)
    }

    /// Generates INI content from a ClientConfig.
    func configToINI(_ config: ClientConfig) -> String {
        var sections: [String: [String: String]] = [:]

        // Common section
        var common: [String: String] = [:]
        if !config.serverAddr.isEmpty { common["server_addr"] = config.serverAddr }
        if config.serverPort != 7000 { common["server_port"] = "\(config.serverPort)" }
        if !config.user.isEmpty { common["user"] = config.user }
        if !config.authMethod.isEmpty { common["authentication_method"] = config.authMethod }
        if !config.token.isEmpty { common["token"] = config.token }
        if config.logLevel != "info" { common["log_level"] = config.logLevel }
        if config.logMaxDays != 3 { common["log_max_days"] = "\(config.logMaxDays)" }
        if !config.adminAddr.isEmpty { common["admin_addr"] = config.adminAddr }
        if config.adminPort != 0 { common["admin_port"] = "\(config.adminPort)" }
        if !config.adminUser.isEmpty { common["admin_user"] = config.adminUser }
        if !config.adminPwd.isEmpty { common["admin_pwd"] = config.adminPwd }
        if config.protocol != "tcp" { common["protocol"] = config.protocol }
        if config.tlsEnable { common["tls_enable"] = "true" }
        if !config.tlsServerName.isEmpty { common["tls_server_name"] = config.tlsServerName }
        if config.connectPoolSize > 0 { common["pool_count"] = "\(config.connectPoolSize)" }
        if !config.dnsServer.isEmpty { common["dns_server"] = config.dnsServer }
        if !config.tcpMux { common["tcp_mux"] = "false" }
        if !config.loginFailExit { common["login_fail_exit"] = "false" }
        if config.heartbeatInterval != 30 { common["heartbeat_interval"] = "\(config.heartbeatInterval)" }
        if config.heartbeatTimeout != 90 { common["heartbeat_timeout"] = "\(config.heartbeatTimeout)" }

        sections["common"] = common

        // Proxy sections
        for proxy in config.proxies {
            var p: [String: String] = [:]
            p["type"] = proxy.type
            if proxy.disabled { p["disabled"] = "true" }
            if proxy.localIP != "127.0.0.1" { p["local_ip"] = proxy.localIP }
            if !proxy.localPort.isEmpty { p["local_port"] = proxy.localPort }
            if !proxy.remotePort.isEmpty { p["remote_port"] = proxy.remotePort }

            // P2P
            if ["xtcp", "stcp", "sudp"].contains(proxy.type) {
                if proxy.role != "server" { p["role"] = proxy.role }
                if !proxy.secretKey.isEmpty { p["sk"] = proxy.secretKey }
            }

            // Domain
            if ["http", "https", "tcpmux"].contains(proxy.type) {
                if !proxy.subdomain.isEmpty { p["subdomain"] = proxy.subdomain }
                if !proxy.customDomains.isEmpty { p["custom_domains"] = proxy.customDomains.joined(separator: ",") }
                if !proxy.locations.isEmpty { p["locations"] = proxy.locations.joined(separator: ",") }
            }

            // HTTP auth
            if !proxy.httpUser.isEmpty { p["http_user"] = proxy.httpUser }
            if !proxy.httpPwd.isEmpty { p["http_pwd"] = proxy.httpPwd }
            if !proxy.hostHeaderRewrite.isEmpty { p["host_header_rewrite"] = proxy.hostHeaderRewrite }

            // Bandwidth
            if proxy.bandwidth.limit > 0 {
                p["bandwidth_limit"] = "\(proxy.bandwidth.limit)\(proxy.bandwidth.unit)"
            }

            // Plugin
            if !proxy.plugin.name.isEmpty {
                p["plugin"] = proxy.plugin.name
                if !proxy.plugin.localAddr.isEmpty { p["plugin_local_addr"] = proxy.plugin.localAddr }
                if !proxy.plugin.httpUser.isEmpty { p["plugin_http_user"] = proxy.plugin.httpUser }
                if !proxy.plugin.httpPwd.isEmpty { p["plugin_http_passwd"] = proxy.plugin.httpPwd }
                if !proxy.plugin.localPath.isEmpty { p["plugin_local_path"] = proxy.plugin.localPath }
                if !proxy.plugin.stripPrefix.isEmpty { p["plugin_strip_prefix"] = proxy.plugin.stripPrefix }
                if !proxy.plugin.unixPath.isEmpty { p["plugin_unix_path"] = proxy.plugin.unixPath }
            }

            // Load balance
            if !proxy.loadBalance.group.isEmpty { p["group"] = proxy.loadBalance.group }
            if !proxy.loadBalance.groupKey.isEmpty { p["group_key"] = proxy.loadBalance.groupKey }

            // Health check
            if !proxy.healthCheck.type.isEmpty {
                p["health_check_type"] = proxy.healthCheck.type
                if !proxy.healthCheck.url.isEmpty { p["health_check_url"] = proxy.healthCheck.url }
                if proxy.healthCheck.timeout > 0 { p["health_check_timeout_s"] = "\(proxy.healthCheck.timeout)" }
                if proxy.healthCheck.interval > 0 { p["health_check_interval_s"] = "\(proxy.healthCheck.interval)" }
                if proxy.healthCheck.maxFailed > 0 { p["health_check_max_failed"] = "\(proxy.healthCheck.maxFailed)" }
            }

            if proxy.useEncryption { p["use_encryption"] = "true" }
            if proxy.useCompression { p["use_compression"] = "true" }

            sections[proxy.name] = p
        }

        return INIParser.serialize(sections)
    }

    // MARK: - Content to Config

    /// Parses TOML content into a ClientConfig.
    func tomlToConfig(_ content: String, name: String) -> ClientConfig {
        let dict = TOMLParser.parse(content)
        return TOMLParser.dictToClientConfig(dict, name: name)
    }

    /// Parses INI content into a ClientConfig.
    func iniToConfig(_ content: String, name: String) -> ClientConfig {
        let sections = INIParser.parse(content)

        var config = ClientConfig(name: name)
        let common = sections["common"] ?? [:]

        // Basic
        config.serverAddr = common["server_addr"] ?? ""
        config.serverPort = Int(common["server_port"] ?? "") ?? 7000
        config.user = common["user"] ?? ""

        // Auth
        config.authMethod = common["authentication_method"] ?? ""
        config.token = common["token"] ?? ""

        // Log
        config.logLevel = common["log_level"] ?? "info"
        config.logMaxDays = Int(common["log_max_days"] ?? "") ?? 3

        // Admin
        config.adminAddr = common["admin_addr"] ?? ""
        config.adminPort = Int(common["admin_port"] ?? "") ?? 0
        config.adminUser = common["admin_user"] ?? ""
        config.adminPwd = common["admin_pwd"] ?? ""

        // Connection
        config.protocol = common["protocol"] ?? "tcp"
        config.connectPoolSize = Int(common["pool_count"] ?? "") ?? 0
        config.heartbeatInterval = Int(common["heartbeat_interval"] ?? "") ?? 30
        config.heartbeatTimeout = Int(common["heartbeat_timeout"] ?? "") ?? 90

        // TLS
        config.tlsEnable = common["tls_enable"] == "true"
        config.tlsServerName = common["tls_server_name"] ?? ""

        // Advanced
        config.dnsServer = common["dns_server"] ?? ""
        config.tcpMux = common["tcp_mux"] != "false"
        config.loginFailExit = common["login_fail_exit"] != "false"
        config.legacyFormat = true

        // Proxies
        for (section, values) in sections where section != "common" && !section.isEmpty {
            var proxy = ProxyConfig(name: section)
            proxy.type = values["type"] ?? "tcp"
            proxy.disabled = values["disabled"] == "true"
            proxy.localIP = values["local_ip"] ?? "127.0.0.1"
            proxy.localPort = values["local_port"] ?? ""
            proxy.remotePort = values["remote_port"] ?? ""

            // P2P
            proxy.role = values["role"] ?? "server"
            proxy.secretKey = values["sk"] ?? ""

            // Domain
            proxy.subdomain = values["subdomain"] ?? ""
            if let domains = values["custom_domains"], !domains.isEmpty {
                proxy.customDomains = domains.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
            if let locs = values["locations"], !locs.isEmpty {
                proxy.locations = locs.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }

            // HTTP
            proxy.httpUser = values["http_user"] ?? ""
            proxy.httpPwd = values["http_pwd"] ?? ""
            proxy.hostHeaderRewrite = values["host_header_rewrite"] ?? ""

            // Plugin
            proxy.plugin.name = values["plugin"] ?? ""
            proxy.plugin.localAddr = values["plugin_local_addr"] ?? ""
            proxy.plugin.httpUser = values["plugin_http_user"] ?? ""
            proxy.plugin.httpPwd = values["plugin_http_passwd"] ?? ""
            proxy.plugin.localPath = values["plugin_local_path"] ?? ""
            proxy.plugin.stripPrefix = values["plugin_strip_prefix"] ?? ""
            proxy.plugin.unixPath = values["plugin_unix_path"] ?? ""

            // Load balance
            proxy.loadBalance.group = values["group"] ?? ""
            proxy.loadBalance.groupKey = values["group_key"] ?? ""

            // Health check
            proxy.healthCheck.type = values["health_check_type"] ?? ""
            proxy.healthCheck.url = values["health_check_url"] ?? ""
            proxy.healthCheck.timeout = Int(values["health_check_timeout_s"] ?? "") ?? 0
            proxy.healthCheck.interval = Int(values["health_check_interval_s"] ?? "") ?? 0
            proxy.healthCheck.maxFailed = Int(values["health_check_max_failed"] ?? "") ?? 0

            proxy.useEncryption = values["use_encryption"] == "true"
            proxy.useCompression = values["use_compression"] == "true"

            // Bandwidth
            if let bw = values["bandwidth_limit"], !bw.isEmpty {
                let parsed = StringUtils.parseBandwidth(bw)
                proxy.bandwidth.limit = parsed.limit
                if !parsed.unit.isEmpty { proxy.bandwidth.unit = parsed.unit }
            }

            config.proxies.append(proxy)
        }

        return config
    }

    // MARK: - Format Detection

    /// Detects whether content is TOML or INI format.
    /// TOML uses `[[proxies]]` array-of-tables syntax and dotted keys; INI uses `[section]` with `key = value`.
    func detectFormat(_ content: String) -> ConfigFormat {
        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // TOML-specific patterns
            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                return .toml
            }
            // Dotted keys like serverAddr, transport.protocol are TOML style
            if trimmed.contains(".") && trimmed.contains("=") && !trimmed.hasPrefix("#") && !trimmed.hasPrefix(";") {
                let key = trimmed.components(separatedBy: "=").first?.trimmingCharacters(in: .whitespaces) ?? ""
                if key.contains(".") {
                    return .toml
                }
            }
            // INI-specific: snake_case keys like server_addr, server_port
            if (trimmed.contains("server_addr") || trimmed.contains("server_port")
                || trimmed.contains("local_port") || trimmed.contains("remote_port")
                || trimmed.contains("log_level")) && trimmed.contains("=") {
                return .ini
            }
        }

        // Default to TOML for modern frp
        return .toml
    }
}
