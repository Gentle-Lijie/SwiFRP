import Foundation

class UpdateChecker {
    static let shared = UpdateChecker()

    var owner: String = "koho"
    var repo: String = "SwiFRP"

    private init() {}

    // MARK: - Public

    func checkForUpdate() async throws -> UpdateInfo? {
        let release = try await NetworkUtils.checkGitHubRelease(owner: owner, repo: repo)

        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let currentVersion = Constants.appVersion

        guard isNewer(latestVersion, than: currentVersion) else {
            return nil
        }

        let downloadURL: URL
        if let macAsset = release.assets.first(where: { $0.name.contains("mac") || $0.name.hasSuffix(".dmg") || $0.name.hasSuffix(".zip") }) {
            downloadURL = URL(string: macAsset.browserDownloadURL) ?? URL(string: release.htmlURL)!
        } else {
            downloadURL = URL(string: release.htmlURL)!
        }

        var publishedDate = Date()
        if let dateString = release.publishedAt {
            let formatter = ISO8601DateFormatter()
            if let parsed = formatter.date(from: dateString) {
                publishedDate = parsed
            }
        }

        return UpdateInfo(
            version: latestVersion,
            downloadURL: downloadURL,
            releaseNotes: release.body,
            publishedAt: publishedDate
        )
    }

    // MARK: - Semver Comparison

    private func isNewer(_ version: String, than current: String) -> Bool {
        let v1 = parseVersion(version)
        let v2 = parseVersion(current)

        if v1.major != v2.major { return v1.major > v2.major }
        if v1.minor != v2.minor { return v1.minor > v2.minor }
        return v1.patch > v2.patch
    }

    private func parseVersion(_ version: String) -> (major: Int, minor: Int, patch: Int) {
        let parts = version.components(separatedBy: ".").compactMap { Int($0) }
        return (
            major: parts.count > 0 ? parts[0] : 0,
            minor: parts.count > 1 ? parts[1] : 0,
            patch: parts.count > 2 ? parts[2] : 0
        )
    }
}

// MARK: - UpdateInfo

struct UpdateInfo {
    var version: String
    var downloadURL: URL
    var releaseNotes: String
    var publishedAt: Date
}
