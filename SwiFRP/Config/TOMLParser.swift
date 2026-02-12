import Foundation

/// A lightweight TOML parser and serializer for FRP configuration files.
struct TOMLParser {

    // MARK: - Parse

    /// Parses a TOML string into a dictionary.
    /// Top-level keys go into the root dict. `[section]` creates nested dicts.
    /// `[[array_of_tables]]` appends dicts to an array under that key.
    static func parse(_ content: String) -> [String: Any] {
        var result: [String: Any] = [:]
        var currentSection: String?
        var isArrayTable = false
        var multilineKey: String?
        var multilineValue = ""
        var multilineDelimiter = ""

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            // Handle multiline strings
            if let key = multilineKey {
                if line.contains(multilineDelimiter) {
                    let endIndex = line.range(of: multilineDelimiter)!.lowerBound
                    multilineValue += String(line[line.startIndex..<endIndex])
                    setValue(multilineValue, forKey: key, in: &result, section: currentSection, isArrayTable: isArrayTable)
                    multilineKey = nil
                    multilineValue = ""
                    multilineDelimiter = ""
                } else {
                    multilineValue += line + "\n"
                }
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Array of tables: [[section]]
            if trimmed.hasPrefix("[[") && trimmed.hasSuffix("]]") {
                let name = String(trimmed.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                currentSection = name
                isArrayTable = true
                // Initialize array if needed and append a new empty dict
                var arr = result[name] as? [[String: Any]] ?? []
                arr.append([:])
                result[name] = arr
                continue
            }

            // Standard table: [section]
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst(1).dropLast(1)).trimmingCharacters(in: .whitespaces)
                currentSection = name
                isArrayTable = false
                if result[name] == nil {
                    result[name] = [String: Any]()
                }
                continue
            }

            // Key-value pair
            guard let eqRange = trimmed.range(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let rawValue = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Check for multiline string start
            if rawValue.hasPrefix("\"\"\"") {
                let after = String(rawValue.dropFirst(3))
                if after.contains("\"\"\"") {
                    let endIdx = after.range(of: "\"\"\"")!.lowerBound
                    let value = String(after[after.startIndex..<endIdx])
                    setValue(value, forKey: key, in: &result, section: currentSection, isArrayTable: isArrayTable)
                } else {
                    multilineKey = key
                    multilineValue = after + "\n"
                    multilineDelimiter = "\"\"\""
                }
                continue
            }

            let parsed = parseValue(rawValue)
            setValue(parsed, forKey: key, in: &result, section: currentSection, isArrayTable: isArrayTable)
        }

        return result
    }

    // MARK: - Serialize

    /// Serializes a dictionary to a TOML-formatted string.
    static func serialize(_ dict: [String: Any]) -> String {
        var lines: [String] = []
        var sections: [(String, Any)] = []

        // Write top-level scalar values first
        for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
            if value is [String: Any] || value is [[String: Any]] {
                sections.append((key, value))
            } else {
                lines.append("\(key) = \(formatValue(value))")
            }
        }

        // Write sections
        for (key, value) in sections {
            if let dictValue = value as? [String: Any] {
                if !lines.isEmpty { lines.append("") }
                lines.append("[\(key)]")
                for (k, v) in dictValue.sorted(by: { $0.key < $1.key }) {
                    lines.append("\(k) = \(formatValue(v))")
                }
            } else if let arrayValue = value as? [[String: Any]] {
                for item in arrayValue {
                    if !lines.isEmpty { lines.append("") }
                    lines.append("[[\(key)]]")
                    for (k, v) in item.sorted(by: { $0.key < $1.key }) {
                        lines.append("\(k) = \(formatValue(v))")
                    }
                }
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - ClientConfig Conversion

    /// Converts a ClientConfig to a TOML-compatible dictionary.
    /// New frp format (v0.52+): No [common] section, settings directly at root level.
    static func clientConfigToDict(_ config: ClientConfig) -> [String: Any] {
        var dict: [String: Any] = [:]

        // Basic settings (directly at root level, not in [common])
        if !config.serverAddr.isEmpty { dict["serverAddr"] = config.serverAddr }
        if config.serverPort != 7000 { dict["serverPort"] = config.serverPort }
        if !config.user.isEmpty { dict["user"] = config.user }
        if !config.natHoleSTUNServer.isEmpty { dict["natHoleSTUNServer"] = config.natHoleSTUNServer }

        // Auth
        if !config.authMethod.isEmpty { dict["auth.method"] = config.authMethod }
        if !config.token.isEmpty { dict["auth.token"] = config.token }
        if !config.tokenFile.isEmpty { dict["auth.tokenFile"] = config.tokenFile }
        if !config.oidcClientID.isEmpty { dict["auth.oidc.clientID"] = config.oidcClientID }
        if !config.oidcClientSecret.isEmpty { dict["auth.oidc.clientSecret"] = config.oidcClientSecret }
        if !config.oidcAudience.isEmpty { dict["auth.oidc.audience"] = config.oidcAudience }
        if !config.oidcScope.isEmpty { dict["auth.oidc.scope"] = config.oidcScope }
        if !config.oidcTokenEndpoint.isEmpty { dict["auth.oidc.tokenEndpointURL"] = config.oidcTokenEndpoint }
        var additionalScopes: [String] = []
        if config.authHeartbeat { additionalScopes.append("HeartBeats") }
        if config.authNewWorkConn { additionalScopes.append("NewWorkConns") }
        if !additionalScopes.isEmpty { dict["auth.additionalScopes"] = additionalScopes }

        // Log
        if config.logLevel != "info" { dict["log.level"] = config.logLevel }
        if config.logMaxDays != 3 { dict["log.maxDays"] = config.logMaxDays }

        // Admin (always set addr and port for admin API)
        // Admin API should always listen on localhost for security
        if config.adminPort > 0 {
            dict["webServer.addr"] = config.adminAddr.isEmpty ? "127.0.0.1" : config.adminAddr
            dict["webServer.port"] = config.adminPort
            if !config.adminUser.isEmpty { dict["webServer.user"] = config.adminUser }
            if !config.adminPwd.isEmpty { dict["webServer.password"] = config.adminPwd }
            if config.adminTLS { dict["webServer.tls.certFile"] = config.adminTLSCertFile }
        }

        // Connection
        if config.protocol != "tcp" { dict["transport.protocol"] = config.protocol }
        if config.dialTimeout != 10 { dict["transport.dialServerTimeout"] = config.dialTimeout }
        if config.keepalivePeriod != 30 { dict["transport.dialServerKeepAlive"] = config.keepalivePeriod }
        if config.connectPoolSize > 0 { dict["transport.poolCount"] = config.connectPoolSize }
        if config.heartbeatInterval != 30 { dict["transport.heartbeatInterval"] = config.heartbeatInterval }
        if config.heartbeatTimeout != 90 { dict["transport.heartbeatTimeout"] = config.heartbeatTimeout }

        // TLS
        if config.tlsEnable { dict["transport.tls.enable"] = true }
        if !config.tlsServerName.isEmpty { dict["transport.tls.serverName"] = config.tlsServerName }
        if !config.tlsCertFile.isEmpty { dict["transport.tls.certFile"] = config.tlsCertFile }
        if !config.tlsKeyFile.isEmpty { dict["transport.tls.keyFile"] = config.tlsKeyFile }
        if !config.tlsTrustedCaFile.isEmpty { dict["transport.tls.trustedCaFile"] = config.tlsTrustedCaFile }

        // Advanced
        if !config.dnsServer.isEmpty { dict["dnsServer"] = config.dnsServer }
        if !config.connectServerLocalIP.isEmpty { dict["transport.connectServerLocalIP"] = config.connectServerLocalIP }
        if !config.tcpMux { dict["transport.tcpMux"] = false }
        if config.tcpMuxKeepAliveInterval != 60 { dict["transport.tcpMuxKeepaliveInterval"] = config.tcpMuxKeepAliveInterval }
        if !config.loginFailExit { dict["loginFailExit"] = false }

        if !config.metadatas.isEmpty { dict["metadatas"] = config.metadatas }

        // Proxies
        if !config.proxies.isEmpty {
            dict["proxies"] = config.proxies.map { proxyConfigToDict($0) }
        }

        return dict
    }

    /// Converts a ProxyConfig to a TOML-compatible dictionary.
    static func proxyConfigToDict(_ proxy: ProxyConfig) -> [String: Any] {
        var dict: [String: Any] = [:]
        dict["name"] = proxy.name
        dict["type"] = proxy.type
        if proxy.disabled { dict["disabled"] = true }

        // Local
        if proxy.localIP != "127.0.0.1" { dict["localIP"] = proxy.localIP }
        if let lp = proxy.localPort { dict["localPort"] = lp }
        if let rp = proxy.remotePort { dict["remotePort"] = rp }

        // P2P
        let p2pTypes = ["xtcp", "stcp", "sudp"]
        if p2pTypes.contains(proxy.type) {
            if !proxy.secretKey.isEmpty { dict["secretKey"] = proxy.secretKey }
            if proxy.role != "server" { dict["role"] = proxy.role }
            if !proxy.allowUsers.isEmpty { dict["allowUsers"] = proxy.allowUsers }
            if !proxy.serverName.isEmpty { dict["serverName"] = proxy.serverName }
            if !proxy.serverUser.isEmpty { dict["serverUser"] = proxy.serverUser }
            if !proxy.bindAddr.isEmpty { dict["bindAddr"] = proxy.bindAddr }
            if proxy.bindPort != 0 { dict["bindPort"] = proxy.bindPort }
        }

        // Domain
        let domainTypes = ["http", "https", "tcpmux"]
        if domainTypes.contains(proxy.type) {
            if !proxy.subdomain.isEmpty { dict["subdomain"] = proxy.subdomain }
            if !proxy.customDomains.isEmpty { dict["customDomains"] = proxy.customDomains }
            if !proxy.locations.isEmpty { dict["locations"] = proxy.locations }
            if !proxy.multiplexer.isEmpty { dict["multiplexer"] = proxy.multiplexer }
            if !proxy.routeByHTTPUser.isEmpty { dict["routeByHTTPUser"] = proxy.routeByHTTPUser }
        }

        // Bandwidth
        if proxy.bandwidth.limit > 0 {
            dict["transport.bandwidthLimit"] = "\(proxy.bandwidth.limit)\(proxy.bandwidth.unit)"
            if proxy.bandwidth.mode != "client" {
                dict["transport.bandwidthLimitMode"] = proxy.bandwidth.mode
            }
        }

        // Advanced
        if !proxy.proxyProtocolVersion.isEmpty { dict["transport.proxyProtocolVersion"] = proxy.proxyProtocolVersion }
        if proxy.useEncryption { dict["transport.useEncryption"] = true }
        if proxy.useCompression { dict["transport.useCompression"] = true }

        // HTTP
        if !proxy.httpUser.isEmpty { dict["httpUser"] = proxy.httpUser }
        if !proxy.httpPwd.isEmpty { dict["httpPassword"] = proxy.httpPwd }
        if !proxy.hostHeaderRewrite.isEmpty { dict["hostHeaderRewrite"] = proxy.hostHeaderRewrite }
        if !proxy.requestHeaders.isEmpty { dict["requestHeaders.set"] = proxy.requestHeaders }
        if !proxy.responseHeaders.isEmpty { dict["responseHeaders.set"] = proxy.responseHeaders }

        // Plugin
        if !proxy.plugin.name.isEmpty {
            dict["plugin.type"] = proxy.plugin.name
            if !proxy.plugin.localAddr.isEmpty { dict["plugin.localAddr"] = proxy.plugin.localAddr }
            if !proxy.plugin.httpUser.isEmpty { dict["plugin.httpUser"] = proxy.plugin.httpUser }
            if !proxy.plugin.httpPwd.isEmpty { dict["plugin.httpPassword"] = proxy.plugin.httpPwd }
            if !proxy.plugin.localPath.isEmpty { dict["plugin.localPath"] = proxy.plugin.localPath }
            if !proxy.plugin.stripPrefix.isEmpty { dict["plugin.stripPrefix"] = proxy.plugin.stripPrefix }
            if !proxy.plugin.unixPath.isEmpty { dict["plugin.unixPath"] = proxy.plugin.unixPath }
        }

        // Load balance
        if !proxy.loadBalance.group.isEmpty { dict["loadBalancer.group"] = proxy.loadBalance.group }
        if !proxy.loadBalance.groupKey.isEmpty { dict["loadBalancer.groupKey"] = proxy.loadBalance.groupKey }

        // Health check
        if !proxy.healthCheck.type.isEmpty {
            dict["healthCheck.type"] = proxy.healthCheck.type
            if !proxy.healthCheck.url.isEmpty { dict["healthCheck.path"] = proxy.healthCheck.url }
            if proxy.healthCheck.timeout > 0 { dict["healthCheck.timeoutSeconds"] = proxy.healthCheck.timeout }
            if proxy.healthCheck.interval > 0 { dict["healthCheck.intervalSeconds"] = proxy.healthCheck.interval }
            if proxy.healthCheck.maxFailed > 0 { dict["healthCheck.maxFailed"] = proxy.healthCheck.maxFailed }
        }

        if !proxy.metadatas.isEmpty { dict["metadatas"] = proxy.metadatas }
        if !proxy.annotations.isEmpty { dict["annotations"] = proxy.annotations }

        return dict
    }

    /// Converts a TOML dictionary to a ClientConfig.
    /// Supports both old format (with [common] section) and new format (root-level settings).
    static func dictToClientConfig(_ dict: [String: Any], name: String) -> ClientConfig {
        // Support both old format (with [common] section) and new format (root level)
        let settings = dict["common"] as? [String: Any] ?? dict

        var config = ClientConfig(name: name)
        config.serverAddr = settings["serverAddr"] as? String ?? ""
        config.serverPort = settings["serverPort"] as? Int ?? 7000
        config.user = settings["user"] as? String ?? ""
        config.natHoleSTUNServer = settings["natHoleSTUNServer"] as? String ?? ""

        // Auth
        config.authMethod = settings["auth.method"] as? String ?? ""
        config.token = settings["auth.token"] as? String ?? ""
        config.tokenFile = settings["auth.tokenFile"] as? String ?? ""
        config.oidcClientID = settings["auth.oidc.clientID"] as? String ?? ""
        config.oidcClientSecret = settings["auth.oidc.clientSecret"] as? String ?? ""
        config.oidcAudience = settings["auth.oidc.audience"] as? String ?? ""
        config.oidcScope = settings["auth.oidc.scope"] as? String ?? ""
        config.oidcTokenEndpoint = settings["auth.oidc.tokenEndpointURL"] as? String ?? ""

        if let scopes = settings["auth.additionalScopes"] as? [String] {
            config.authHeartbeat = scopes.contains("HeartBeats")
            config.authNewWorkConn = scopes.contains("NewWorkConns")
        }

        // Log
        config.logLevel = settings["log.level"] as? String ?? "info"
        config.logMaxDays = settings["log.maxDays"] as? Int ?? 3

        // Admin
        config.adminAddr = settings["webServer.addr"] as? String ?? "127.0.0.1"
        config.adminPort = settings["webServer.port"] as? Int ?? 0
        config.adminUser = settings["webServer.user"] as? String ?? ""
        config.adminPwd = settings["webServer.password"] as? String ?? ""

        // Connection
        config.protocol = settings["transport.protocol"] as? String ?? "tcp"
        config.dialTimeout = settings["transport.dialServerTimeout"] as? Int ?? 10
        config.keepalivePeriod = settings["transport.dialServerKeepAlive"] as? Int ?? 30
        config.connectPoolSize = settings["transport.poolCount"] as? Int ?? 0
        config.heartbeatInterval = settings["transport.heartbeatInterval"] as? Int ?? 30
        config.heartbeatTimeout = settings["transport.heartbeatTimeout"] as? Int ?? 90

        // TLS
        config.tlsEnable = settings["transport.tls.enable"] as? Bool ?? false
        config.tlsServerName = settings["transport.tls.serverName"] as? String ?? ""
        config.tlsCertFile = settings["transport.tls.certFile"] as? String ?? ""
        config.tlsKeyFile = settings["transport.tls.keyFile"] as? String ?? ""
        config.tlsTrustedCaFile = settings["transport.tls.trustedCaFile"] as? String ?? ""

        // Advanced
        config.dnsServer = settings["dnsServer"] as? String ?? ""
        config.connectServerLocalIP = settings["transport.connectServerLocalIP"] as? String ?? ""
        config.tcpMux = settings["transport.tcpMux"] as? Bool ?? true
        config.tcpMuxKeepAliveInterval = settings["transport.tcpMuxKeepaliveInterval"] as? Int ?? 60
        config.loginFailExit = settings["loginFailExit"] as? Bool ?? true

        if let metadatas = settings["metadatas"] as? [String: String] {
            config.metadatas = metadatas
        }

        // Proxies
        if let proxies = dict["proxies"] as? [[String: Any]] {
            config.proxies = proxies.map { dictToProxyConfig($0) }
        }

        return config
    }

    /// Converts a TOML dictionary to a ProxyConfig.
    static func dictToProxyConfig(_ dict: [String: Any]) -> ProxyConfig {
        var proxy = ProxyConfig(name: dict["name"] as? String ?? "unnamed")
        proxy.type = dict["type"] as? String ?? "tcp"
        proxy.disabled = dict["disabled"] as? Bool ?? false

        proxy.localIP = dict["localIP"] as? String ?? "127.0.0.1"
        if let lp = dict["localPort"] {
            proxy.localPort = lp as? Int ?? Int("\(lp)")
        }
        if let rp = dict["remotePort"] {
            proxy.remotePort = rp as? Int ?? Int("\(rp)")
        }

        // P2P
        proxy.secretKey = dict["secretKey"] as? String ?? ""
        proxy.role = dict["role"] as? String ?? "server"
        proxy.allowUsers = dict["allowUsers"] as? [String] ?? []
        proxy.serverName = dict["serverName"] as? String ?? ""
        proxy.serverUser = dict["serverUser"] as? String ?? ""
        proxy.bindAddr = dict["bindAddr"] as? String ?? ""
        proxy.bindPort = dict["bindPort"] as? Int ?? 0

        // Domain
        proxy.subdomain = dict["subdomain"] as? String ?? ""
        proxy.customDomains = dict["customDomains"] as? [String] ?? []
        proxy.locations = dict["locations"] as? [String] ?? []
        proxy.multiplexer = dict["multiplexer"] as? String ?? ""
        proxy.routeByHTTPUser = dict["routeByHTTPUser"] as? String ?? ""

        // Bandwidth
        if let bw = dict["transport.bandwidthLimit"] as? String {
            let parsed = StringUtils.parseBandwidth(bw)
            proxy.bandwidth.limit = parsed.limit
            proxy.bandwidth.unit = parsed.unit
        }
        proxy.bandwidth.mode = dict["transport.bandwidthLimitMode"] as? String ?? "client"

        // Advanced
        proxy.proxyProtocolVersion = dict["transport.proxyProtocolVersion"] as? String ?? ""
        proxy.useEncryption = dict["transport.useEncryption"] as? Bool ?? false
        proxy.useCompression = dict["transport.useCompression"] as? Bool ?? false

        // HTTP
        proxy.httpUser = dict["httpUser"] as? String ?? ""
        proxy.httpPwd = dict["httpPassword"] as? String ?? ""
        proxy.hostHeaderRewrite = dict["hostHeaderRewrite"] as? String ?? ""
        proxy.requestHeaders = dict["requestHeaders.set"] as? [String: String] ?? [:]
        proxy.responseHeaders = dict["responseHeaders.set"] as? [String: String] ?? [:]

        // Plugin
        proxy.plugin.name = dict["plugin.type"] as? String ?? ""
        proxy.plugin.localAddr = dict["plugin.localAddr"] as? String ?? ""
        proxy.plugin.httpUser = dict["plugin.httpUser"] as? String ?? ""
        proxy.plugin.httpPwd = dict["plugin.httpPassword"] as? String ?? ""
        proxy.plugin.localPath = dict["plugin.localPath"] as? String ?? ""
        proxy.plugin.stripPrefix = dict["plugin.stripPrefix"] as? String ?? ""
        proxy.plugin.unixPath = dict["plugin.unixPath"] as? String ?? ""

        // Load balance
        proxy.loadBalance.group = dict["loadBalancer.group"] as? String ?? ""
        proxy.loadBalance.groupKey = dict["loadBalancer.groupKey"] as? String ?? ""

        // Health check
        proxy.healthCheck.type = dict["healthCheck.type"] as? String ?? ""
        proxy.healthCheck.url = dict["healthCheck.path"] as? String ?? ""
        proxy.healthCheck.timeout = dict["healthCheck.timeoutSeconds"] as? Int ?? 0
        proxy.healthCheck.interval = dict["healthCheck.intervalSeconds"] as? Int ?? 0
        proxy.healthCheck.maxFailed = dict["healthCheck.maxFailed"] as? Int ?? 0

        proxy.metadatas = dict["metadatas"] as? [String: String] ?? [:]
        proxy.annotations = dict["annotations"] as? [String: String] ?? [:]

        return proxy
    }

    // MARK: - Private Helpers

    private static func parseValue(_ raw: String) -> Any {
        // Remove inline comments (outside of strings)
        let value = stripInlineComment(raw)

        // Boolean
        if value == "true" { return true }
        if value == "false" { return false }

        // Integer
        if let intVal = Int(value) { return intVal }

        // Quoted string
        if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }

        // Single-quoted string
        if value.hasPrefix("'") && value.hasSuffix("'") && value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }

        // Array: [val1, val2, ...]
        if value.hasPrefix("[") && value.hasSuffix("]") {
            let inner = String(value.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            if inner.isEmpty { return [String]() }
            return inner.components(separatedBy: ",").map { item in
                let trimmed = item.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count >= 2 {
                    return String(trimmed.dropFirst().dropLast())
                }
                return trimmed
            }
        }

        // Bare string
        return value
    }

    private static func stripInlineComment(_ value: String) -> String {
        var inQuote = false
        var quoteChar: Character = "\""
        for (i, ch) in value.enumerated() {
            if ch == "\"" || ch == "'" {
                if !inQuote {
                    inQuote = true
                    quoteChar = ch
                } else if ch == quoteChar {
                    inQuote = false
                }
            }
            if ch == "#" && !inQuote {
                let idx = value.index(value.startIndex, offsetBy: i)
                return String(value[..<idx]).trimmingCharacters(in: .whitespaces)
            }
        }
        return value
    }

    private static func setValue(_ value: Any, forKey key: String, in dict: inout [String: Any], section: String?, isArrayTable: Bool) {
        if let section = section {
            if isArrayTable {
                var arr = dict[section] as? [[String: Any]] ?? [[:]]
                var last = arr.removeLast()
                last[key] = value
                arr.append(last)
                dict[section] = arr
            } else {
                var sectionDict = dict[section] as? [String: Any] ?? [:]
                sectionDict[key] = value
                dict[section] = sectionDict
            }
        } else {
            dict[key] = value
        }
    }

    private static func formatValue(_ value: Any) -> String {
        switch value {
        case let str as String:
            return "\"\(str)\""
        case let bool as Bool:
            return bool ? "true" : "false"
        case let int as Int:
            return "\(int)"
        case let int64 as Int64:
            return "\(int64)"
        case let arr as [String]:
            let items = arr.map { "\"\($0)\"" }.joined(separator: ", ")
            return "[\(items)]"
        case let dict as [String: String]:
            let items = dict.sorted(by: { $0.key < $1.key }).map { "\($0.key) = \"\($0.value)\"" }
            return "{ \(items.joined(separator: ", ")) }"
        default:
            return "\"\(value)\""
        }
    }

}
