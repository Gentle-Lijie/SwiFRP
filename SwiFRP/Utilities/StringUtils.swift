import CryptoKit
import Foundation

/// String utility functions for SwiFRP.
struct StringUtils {

    /// Generates a random alphanumeric string of the given length.
    static func generateRandomName(length: Int = 8) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in chars.randomElement()! })
    }

    /// Returns the MD5 hex digest of a string using CryptoKit's Insecure.MD5.
    static func md5Hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Returns the Base64-encoded representation of a string.
    static func base64Encode(_ string: String) -> String {
        Data(string.utf8).base64EncodedString()
    }

    /// Decodes a Base64-encoded string. Returns nil if decoding fails.
    static func base64Decode(_ string: String) -> String? {
        guard let data = Data(base64Encoded: string) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Checks whether a port number is in the valid range (1–65535).
    static func isValidPort(_ port: Int) -> Bool {
        (1...65535).contains(port)
    }

    /// Parses a port range string like "6000-6006,6007,6010-6012" into an array of individual ports.
    static func parsePortRange(_ range: String) -> [Int] {
        var ports: [Int] = []
        let segments = range.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        for segment in segments {
            if segment.contains("-") {
                let bounds = segment.components(separatedBy: "-").map { $0.trimmingCharacters(in: .whitespaces) }
                guard bounds.count == 2,
                      let lower = Int(bounds[0]),
                      let upper = Int(bounds[1]),
                      lower <= upper
                else { continue }
                ports.append(contentsOf: lower...upper)
            } else if let port = Int(segment) {
                ports.append(port)
            }
        }

        return ports
    }

    /// Parses a bandwidth string like "10MB" into (limit, unit) components.
    static func parseBandwidth(_ value: String) -> (limit: Int, unit: String) {
        var digits = ""
        var unit = ""
        for ch in value {
            if ch.isNumber { digits.append(ch) } else { unit.append(ch) }
        }
        return (Int(digits) ?? 0, unit.isEmpty ? "MB" : unit)
    }

    /// Formats a byte count into a human-readable string (e.g., "1.5 MB").
    static func formatBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}
