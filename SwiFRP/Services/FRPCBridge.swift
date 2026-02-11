import Foundation

class FRPCBridge {
    static let shared = FRPCBridge()

    private let session = URLSession.shared

    private init() {}

    // MARK: - Public API

    func fetchProxyStatus(
        adminAddr: String, adminPort: Int, user: String?, password: String?
    ) async throws -> [ProxyStatus] {
        let data = try await request(
            adminAddr: adminAddr, adminPort: adminPort,
            path: "/api/proxy/tcp", user: user, password: password
        )
        let entries = try JSONDecoder().decode([AdminProxyEntry].self, from: data)

        // Also fetch UDP proxies
        let udpData = try? await request(
            adminAddr: adminAddr, adminPort: adminPort,
            path: "/api/proxy/udp", user: user, password: password
        )
        var allEntries = entries
        if let udpData = udpData,
           let udpEntries = try? JSONDecoder().decode([AdminProxyEntry].self, from: udpData) {
            allEntries.append(contentsOf: udpEntries)
        }

        return allEntries.map { entry in
            ProxyStatus(
                name: entry.name,
                type: entry.conf?.type ?? "tcp",
                status: entry.status == "running" ? .running : (entry.status == "error" ? .error : .unknown),
                remoteAddr: entry.remoteAddr ?? "",
                error: entry.err ?? ""
            )
        }
    }

    func reload(
        adminAddr: String, adminPort: Int, user: String?, password: String?
    ) async throws {
        _ = try await request(
            adminAddr: adminAddr, adminPort: adminPort,
            path: "/api/reload", user: user, password: password,
            method: "GET"
        )
    }

    func getConnectionInfo(
        adminAddr: String, adminPort: Int, user: String?, password: String?
    ) async throws -> ConnectionInfo {
        let data = try await request(
            adminAddr: adminAddr, adminPort: adminPort,
            path: "/api/status", user: user, password: password
        )
        let status = try JSONDecoder().decode(AdminStatusResponse.self, from: data)
        return ConnectionInfo(
            tcpCount: status.tcp?.count ?? 0,
            udpCount: status.udp?.count ?? 0
        )
    }

    // MARK: - Internal

    private static let requestTimeout: TimeInterval = 5

    private func request(
        adminAddr: String, adminPort: Int, path: String,
        user: String?, password: String?, method: String = "GET"
    ) async throws -> Data {
        let scheme = "http"
        let host = adminAddr.isEmpty ? "127.0.0.1" : adminAddr
        guard let url = URL(string: "\(scheme)://\(host):\(adminPort)\(path)") else {
            throw FRPCBridgeError.invalidURL
        }

        var request = URLRequest(url: url, timeoutInterval: Self.requestTimeout)
        request.httpMethod = method

        // Basic auth
        if let user = user, !user.isEmpty {
            let credential = "\(user):\(password ?? "")"
            if let credentialData = credential.data(using: .utf8) {
                let base64 = credentialData.base64EncodedString()
                request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw FRPCBridgeError.requestFailed
        }
        return data
    }
}

// MARK: - Models

struct ConnectionInfo {
    var tcpCount: Int
    var udpCount: Int
}

// MARK: - Internal Response Models

private struct AdminProxyEntry: Codable {
    let name: String
    let conf: AdminProxyConf?
    let status: String?
    let remoteAddr: String?
    let err: String?

    enum CodingKeys: String, CodingKey {
        case name, conf, status
        case remoteAddr = "remote_addr"
        case err
    }
}

private struct AdminProxyConf: Codable {
    let type: String?
}

private struct AdminStatusResponse: Codable {
    let tcp: [AdminProxyEntry]?
    let udp: [AdminProxyEntry]?
}

// MARK: - Errors

enum FRPCBridgeError: LocalizedError {
    case invalidURL
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid admin API URL."
        case .requestFailed:
            return "Admin API request failed."
        }
    }
}
