import Foundation

/// A GitHub release model for version checking.
struct GitHubRelease: Codable {
    let tagName: String
    let htmlURL: String
    let body: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case body
        case assets
    }
}

/// A GitHub release asset.
struct GitHubAsset: Codable {
    let name: String
    let size: Int
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case size
        case browserDownloadURL = "browser_download_url"
    }
}

/// Network utility functions for SwiFRP.
struct NetworkUtils {

    /// Checks whether a TCP port is available on the given host by attempting a connection.
    /// Returns `true` if the port is available (connection refused), `false` if in use.
    static func checkPortAvailable(_ port: Int, host: String = "127.0.0.1") -> Bool {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = inet_addr(host)

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        // Set a short timeout for the connection attempt
        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let result = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        // If connect fails, the port is available
        return result != 0
    }

    /// Fetches data from a URL asynchronously.
    static func fetchURL(_ url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw NetworkError.requestFailed(url: url)
        }
        return data
    }

    /// Downloads a file from a URL to a local destination.
    static func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode)
        else {
            throw NetworkError.requestFailed(url: url)
        }

        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tempURL, to: destination)
    }

    /// Checks the latest GitHub release for a given repository.
    static func checkGitHubRelease(owner: String, repo: String) async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        let data = try await fetchURL(url)
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }
}

// MARK: - Errors

enum NetworkError: LocalizedError {
    case requestFailed(url: URL)

    var errorDescription: String? {
        switch self {
        case .requestFailed(let url):
            return "Request failed for URL: \(url.absoluteString)"
        }
    }
}
