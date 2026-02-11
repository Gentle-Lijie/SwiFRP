import Foundation

/// A parser and serializer for legacy INI-format FRP configuration files.
struct INIParser {

    // MARK: - Parse

    /// Parses an INI string into a dictionary of sections, each containing key-value pairs.
    /// Keys outside any section are placed under the empty string key `""`.
    static func parse(_ content: String) -> [String: [String: String]] {
        var result: [String: [String: String]] = [:]
        var currentSection = ""

        let lines = content.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") || trimmed.hasPrefix(";") {
                continue
            }

            // Section header
            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                currentSection = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if result[currentSection] == nil {
                    result[currentSection] = [:]
                }
                continue
            }

            // Key = Value pair
            guard let eqRange = trimmed.range(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[eqRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // Strip inline comments (but not inside quoted values)
            if !value.hasPrefix("\"") {
                if let commentRange = value.range(of: " #") {
                    value = String(value[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
                if let commentRange = value.range(of: " ;") {
                    value = String(value[..<commentRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
            }

            if result[currentSection] == nil {
                result[currentSection] = [:]
            }
            result[currentSection]?[key] = value
        }

        return result
    }

    // MARK: - Serialize

    /// Serializes sections to an INI-formatted string.
    /// The `"common"` section is written first, followed by other sections in sorted order.
    static func serialize(_ sections: [String: [String: String]]) -> String {
        var lines: [String] = []

        // Write "common" section first if it exists
        if let common = sections["common"] {
            lines.append("[common]")
            for (key, value) in common.sorted(by: { $0.key < $1.key }) {
                lines.append("\(key) = \(value)")
            }
        }

        // Write remaining sections
        for (section, values) in sections.sorted(by: { $0.key < $1.key }) {
            if section == "common" || section.isEmpty { continue }
            if !lines.isEmpty { lines.append("") }
            lines.append("[\(section)]")
            for (key, value) in values.sorted(by: { $0.key < $1.key }) {
                lines.append("\(key) = \(value)")
            }
        }

        // Write keys without section last
        if let noSection = sections[""], !noSection.isEmpty {
            if !lines.isEmpty { lines.append("") }
            for (key, value) in noSection.sorted(by: { $0.key < $1.key }) {
                lines.append("\(key) = \(value)")
            }
        }

        return lines.joined(separator: "\n") + "\n"
    }
}
