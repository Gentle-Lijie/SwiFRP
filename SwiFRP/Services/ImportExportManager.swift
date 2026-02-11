#if canImport(AppKit)
import AppKit
#endif
import Foundation

class ImportExportManager {
    static let shared = ImportExportManager()

    private let configFileManager = ConfigFileManager.shared
    private let fm = FileManager.default

    private init() {}

    // MARK: - Import from Files

    func importFromFiles(urls: [URL]) throws -> [ClientConfig] {
        var configs: [ClientConfig] = []
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "zip" {
                let zipConfigs = try configFileManager.importConfigsFromZIP(at: url)
                configs.append(contentsOf: zipConfigs)
            } else if ["toml", "ini", "json", "yml", "yaml"].contains(ext) {
                let config = try configFileManager.importConfigFromFile(at: url)
                configs.append(config)
            }
        }
        return configs
    }

    // MARK: - Import from URLs

    func importFromURLs(_ urls: [String], progress: ((Int, Int) -> Void)? = nil) async throws -> [ClientConfig] {
        var configs: [ClientConfig] = []
        for (index, urlString) in urls.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            let config = try await configFileManager.importConfigFromURL(url)
            configs.append(config)
            progress?(index + 1, urls.count)
        }
        return configs
    }

    // MARK: - Import from Clipboard

    func importFromClipboard() throws -> ClientConfig? {
        #if canImport(AppKit)
        guard let string = NSPasteboard.general.string(forType: .string),
              !string.isEmpty else {
            return nil
        }
        #else
        return nil
        #endif

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Handle frp:// share links
        if trimmed.hasPrefix("frp://") {
            let base64 = String(trimmed.dropFirst(6))
            return try configFileManager.importConfigFromClipboard(base64)
        }

        // Try as raw base64
        if let _ = Data(base64Encoded: trimmed) {
            return try configFileManager.importConfigFromClipboard(trimmed)
        }

        // Try as raw config content
        let converter = ConfigConverter()
        let name = StringUtils.generateRandomName()
        let format = converter.detectFormat(trimmed)
        if format == .ini {
            return converter.iniToConfig(trimmed, name: name)
        }
        return converter.tomlToConfig(trimmed, name: name)
    }

    // MARK: - Export

    func exportToZIP(configs: [ClientConfig]) throws -> URL {
        let tempDir = fm.temporaryDirectory
        let zipURL = tempDir.appendingPathComponent("SwiFRP-configs-\(Date().timeIntervalSince1970).zip")
        try configFileManager.exportAllAsZIP(configs: configs, to: zipURL)
        return zipURL
    }

    // MARK: - Import from ZIP

    func importFromZIPFile(at url: URL) throws -> [ClientConfig] {
        return try configFileManager.importConfigsFromZIP(at: url)
    }
}
