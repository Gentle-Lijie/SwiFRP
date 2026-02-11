import Foundation

enum Constants {

    // MARK: - App Info

    static let appVersion = "0.1.0"
    static let frpVersion = "0.61.1"
    static let buildDate = "2026-02-11"

    // MARK: - Network Protocols

    static let protocols = ["tcp", "kcp", "quic", "websocket", "wss"]

    // MARK: - Proxy Types

    static let proxyTypes = ["tcp", "udp", "xtcp", "stcp", "sudp", "http", "https", "tcpmux"]

    // MARK: - Plugin Types

    static let pluginTypes = [
        "http2http", "http2https", "https2http", "https2https",
        "http_proxy", "socks5", "static_file", "unix_domain_socket", "tls2raw",
    ]

    // MARK: - Auth Methods

    static let authMethods = ["token", "oidc"]

    // MARK: - Log Levels

    static let logLevels = ["trace", "debug", "info", "warn", "error"]

    // MARK: - Defaults

    static let defaultSTUNServer = "stun.easyvoip.com:3478"
    static let defaultServerPort = 7000
}

// MARK: - AppPaths

enum AppPaths {

    private static let fileManager = FileManager.default

    static var appSupportDirectory: URL {
        guard let appSupport = fileManager.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else {
            return fileManager.temporaryDirectory.appendingPathComponent("SwiFRP", isDirectory: true)
        }
        return appSupport.appendingPathComponent("SwiFRP", isDirectory: true)
    }

    static var configDirectory: URL {
        appSupportDirectory.appendingPathComponent("configs", isDirectory: true)
    }

    static var logsDirectory: URL {
        appSupportDirectory.appendingPathComponent("logs", isDirectory: true)
    }

    static var appConfigURL: URL {
        appSupportDirectory.appendingPathComponent("app.json")
    }

    static func configURL(for name: String, legacyFormat: Bool = false) -> URL {
        let ext = legacyFormat ? "ini" : "toml"
        return configDirectory.appendingPathComponent("\(name).\(ext)")
    }

    static func logURL(for name: String) -> URL {
        logsDirectory.appendingPathComponent("\(name).log")
    }

    static func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
    }
}
