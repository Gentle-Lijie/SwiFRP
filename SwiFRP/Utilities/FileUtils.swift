import Foundation

/// File system utility functions for SwiFRP.
struct FileUtils {

    private static let fileManager = FileManager.default

    /// Returns the application support directory for SwiFRP.
    static func appSupportDirectory() -> URL {
        AppPaths.appSupportDirectory
    }

    /// Returns the configs directory.
    static func configsDirectory() -> URL {
        AppPaths.configDirectory
    }

    /// Returns the logs directory.
    static func logsDirectory() -> URL {
        AppPaths.logsDirectory
    }

    /// Ensures all required directories exist (app support, configs, logs).
    static func ensureDirectoriesExist() {
        try? AppPaths.ensureDirectoriesExist()
    }

    /// Returns the file path for a config with the given name and format extension.
    static func configFilePath(name: String, format: String) -> URL {
        configsDirectory().appendingPathComponent("\(name).\(format)")
    }

    /// Returns all log files associated with the given config name.
    static func logFilesForConfig(name: String) -> [URL] {
        let logsDir = logsDirectory()
        guard let contents = try? fileManager.contentsOfDirectory(
            at: logsDir, includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }
        return contents.filter { url in
            let filename = url.lastPathComponent
            return filename.hasPrefix(name) && filename.hasSuffix(".log")
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Calculates the total size in bytes of all log files for a given config.
    static func totalLogSize(name: String) -> Int64 {
        let files = logFilesForConfig(name: name)
        var total: Int64 = 0
        for file in files {
            if let attrs = try? fileManager.attributesOfItem(atPath: file.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    /// Exports the given config file URLs into a ZIP archive at the destination.
    static func exportAllAsZIP(configs: [URL], to destination: URL) throws {
        // Use the built-in ditto command to create a zip archive
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }

        // Copy all config files to temp directory
        for configURL in configs {
            let destFile = tempDir.appendingPathComponent(configURL.lastPathComponent)
            try fileManager.copyItem(at: configURL, to: destFile)
        }

        // Remove existing destination if needed
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        // Create ZIP using Process (ditto)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", tempDir.path, destination.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw FileUtilsError.zipCreationFailed
        }
    }

    /// Imports config files from a ZIP archive, returning URLs of the extracted files.
    static func importFromZIP(at url: URL) throws -> [URL] {
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Unzip using ditto
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", url.path, tempDir.path]
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            try? fileManager.removeItem(at: tempDir)
            throw FileUtilsError.zipExtractionFailed
        }

        // Collect all config files recursively
        var extracted: [URL] = []
        if let enumerator = fileManager.enumerator(
            at: tempDir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) {
            while let fileURL = enumerator.nextObject() as? URL {
                let ext = fileURL.pathExtension.lowercased()
                if ext == "toml" || ext == "ini" {
                    extracted.append(fileURL)
                }
            }
        }

        return extracted
    }
}

// MARK: - Errors

enum FileUtilsError: LocalizedError {
    case zipCreationFailed
    case zipExtractionFailed

    var errorDescription: String? {
        switch self {
        case .zipCreationFailed:
            return "Failed to create ZIP archive."
        case .zipExtractionFailed:
            return "Failed to extract ZIP archive."
        }
    }
}
