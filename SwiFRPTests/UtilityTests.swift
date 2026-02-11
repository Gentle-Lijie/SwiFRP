import XCTest
@testable import SwiFRP

final class UtilityTests: XCTestCase {

    // MARK: - StringUtils.generateRandomName

    func testRandomNameDefaultLength() {
        let name = StringUtils.generateRandomName()
        XCTAssertEqual(name.count, 8)
    }

    func testRandomNameCustomLength() {
        let name = StringUtils.generateRandomName(length: 16)
        XCTAssertEqual(name.count, 16)
    }

    func testRandomNameZeroLength() {
        let name = StringUtils.generateRandomName(length: 0)
        XCTAssertTrue(name.isEmpty)
    }

    func testRandomNameCharacterSet() {
        let name = StringUtils.generateRandomName(length: 100)
        let validChars = CharacterSet.alphanumerics
        for scalar in name.unicodeScalars {
            XCTAssertTrue(validChars.contains(scalar), "Character '\(scalar)' should be alphanumeric")
        }
    }

    func testRandomNameUniqueness() {
        let name1 = StringUtils.generateRandomName(length: 20)
        let name2 = StringUtils.generateRandomName(length: 20)
        // Extremely unlikely to collide with 20-char alphanumeric names
        XCTAssertNotEqual(name1, name2)
    }

    // MARK: - StringUtils.base64

    func testBase64EncodeDecode() {
        let original = "Hello, World!"
        let encoded = StringUtils.base64Encode(original)
        XCTAssertEqual(encoded, "SGVsbG8sIFdvcmxkIQ==")

        let decoded = StringUtils.base64Decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    func testBase64EncodeEmpty() {
        let encoded = StringUtils.base64Encode("")
        XCTAssertEqual(encoded, "")
        let decoded = StringUtils.base64Decode(encoded)
        XCTAssertEqual(decoded, "")
    }

    func testBase64DecodeInvalid() {
        let decoded = StringUtils.base64Decode("!!!not-valid-base64!!!")
        XCTAssertNil(decoded)
    }

    func testBase64RoundtripUnicode() {
        let original = "日本語テスト 🎉"
        let encoded = StringUtils.base64Encode(original)
        let decoded = StringUtils.base64Decode(encoded)
        XCTAssertEqual(decoded, original)
    }

    // MARK: - StringUtils.isValidPort

    func testIsValidPort() {
        XCTAssertTrue(StringUtils.isValidPort(1))
        XCTAssertTrue(StringUtils.isValidPort(80))
        XCTAssertTrue(StringUtils.isValidPort(443))
        XCTAssertTrue(StringUtils.isValidPort(7000))
        XCTAssertTrue(StringUtils.isValidPort(65535))
    }

    func testIsValidPortInvalid() {
        XCTAssertFalse(StringUtils.isValidPort(0))
        XCTAssertFalse(StringUtils.isValidPort(-1))
        XCTAssertFalse(StringUtils.isValidPort(65536))
        XCTAssertFalse(StringUtils.isValidPort(100000))
    }

    // MARK: - StringUtils.parsePortRange

    func testParsePortRangeSingle() {
        let ports = StringUtils.parsePortRange("6000")
        XCTAssertEqual(ports, [6000])
    }

    func testParsePortRangeMultiple() {
        let ports = StringUtils.parsePortRange("6000,6001,6002")
        XCTAssertEqual(ports, [6000, 6001, 6002])
    }

    func testParsePortRangeRange() {
        let ports = StringUtils.parsePortRange("6000-6003")
        XCTAssertEqual(ports, [6000, 6001, 6002, 6003])
    }

    func testParsePortRangeMixed() {
        let ports = StringUtils.parsePortRange("6000-6003,6005")
        XCTAssertEqual(ports, [6000, 6001, 6002, 6003, 6005])
    }

    func testParsePortRangeWithSpaces() {
        let ports = StringUtils.parsePortRange("6000 - 6002, 6005")
        XCTAssertEqual(ports, [6000, 6001, 6002, 6005])
    }

    func testParsePortRangeEmpty() {
        let ports = StringUtils.parsePortRange("")
        XCTAssertTrue(ports.isEmpty)
    }

    func testParsePortRangeInvalidText() {
        let ports = StringUtils.parsePortRange("abc")
        XCTAssertTrue(ports.isEmpty)
    }

    func testParsePortRangeInvertedRange() {
        let ports = StringUtils.parsePortRange("6003-6000")
        XCTAssertTrue(ports.isEmpty)
    }

    // MARK: - StringUtils.formatBytes

    func testFormatBytesZero() {
        XCTAssertEqual(StringUtils.formatBytes(0), "0 B")
    }

    func testFormatBytesSmall() {
        XCTAssertEqual(StringUtils.formatBytes(512), "512 B")
    }

    func testFormatBytesKilobytes() {
        XCTAssertEqual(StringUtils.formatBytes(1024), "1.0 KB")
        XCTAssertEqual(StringUtils.formatBytes(1536), "1.5 KB")
    }

    func testFormatBytesMegabytes() {
        XCTAssertEqual(StringUtils.formatBytes(1048576), "1.0 MB")
        XCTAssertEqual(StringUtils.formatBytes(1572864), "1.5 MB")
    }

    func testFormatBytesGigabytes() {
        XCTAssertEqual(StringUtils.formatBytes(1073741824), "1.0 GB")
    }

    func testFormatBytesTerabytes() {
        XCTAssertEqual(StringUtils.formatBytes(1099511627776), "1.0 TB")
    }

    // MARK: - StringUtils.md5Hash

    func testMD5Hash() {
        XCTAssertEqual(StringUtils.md5Hash(""), "d41d8cd98f00b204e9800998ecf8427e")
        XCTAssertEqual(StringUtils.md5Hash("hello"), "5d41402abc4b2a76b9719d911017c592")
        XCTAssertEqual(StringUtils.md5Hash("Hello, World!"), "65a8e27d8879283831b664bd8b7f0ad4")
    }

    func testMD5HashConsistency() {
        let input = "test string"
        let hash1 = StringUtils.md5Hash(input)
        let hash2 = StringUtils.md5Hash(input)
        XCTAssertEqual(hash1, hash2)
    }

    func testMD5HashLength() {
        let hash = StringUtils.md5Hash("anything")
        XCTAssertEqual(hash.count, 32)
    }

    func testMD5HashHexCharacters() {
        let hash = StringUtils.md5Hash("test")
        let validChars = CharacterSet(charactersIn: "0123456789abcdef")
        for scalar in hash.unicodeScalars {
            XCTAssertTrue(validChars.contains(scalar))
        }
    }

    // MARK: - StringUtils.sha256Hash

    func testSHA256Hash() {
        // SHA-256 of empty string
        XCTAssertEqual(
            StringUtils.sha256Hash(""),
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        )
        // SHA-256 of "hello"
        XCTAssertEqual(
            StringUtils.sha256Hash("hello"),
            "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    func testSHA256HashLength() {
        let hash = StringUtils.sha256Hash("anything")
        XCTAssertEqual(hash.count, 64)
    }

    // MARK: - StringUtils.parseBandwidth

    func testParseBandwidthMB() {
        let result = StringUtils.parseBandwidth("10MB")
        XCTAssertEqual(result.limit, 10)
        XCTAssertEqual(result.unit, "MB")
    }

    func testParseBandwidthKB() {
        let result = StringUtils.parseBandwidth("500KB")
        XCTAssertEqual(result.limit, 500)
        XCTAssertEqual(result.unit, "KB")
    }

    func testParseBandwidthNoUnit() {
        let result = StringUtils.parseBandwidth("100")
        XCTAssertEqual(result.limit, 100)
        XCTAssertEqual(result.unit, "MB")
    }

    func testParseBandwidthEmpty() {
        let result = StringUtils.parseBandwidth("")
        XCTAssertEqual(result.limit, 0)
        XCTAssertEqual(result.unit, "MB")
    }

    // MARK: - NetworkUtils Models

    func testGitHubReleaseCodable() throws {
        let json = """
        {
            "tag_name": "v1.0.0",
            "html_url": "https://github.com/owner/repo/releases/v1.0.0",
            "body": "Release notes",
            "published_at": "2024-01-01T00:00:00Z",
            "assets": [
                {
                    "name": "app.zip",
                    "size": 1024,
                    "browser_download_url": "https://example.com/app.zip"
                }
            ]
        }
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertEqual(release.tagName, "v1.0.0")
        XCTAssertEqual(release.htmlURL, "https://github.com/owner/repo/releases/v1.0.0")
        XCTAssertEqual(release.body, "Release notes")
        XCTAssertEqual(release.publishedAt, "2024-01-01T00:00:00Z")
        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "app.zip")
        XCTAssertEqual(release.assets[0].size, 1024)
        XCTAssertEqual(release.assets[0].browserDownloadURL, "https://example.com/app.zip")
    }

    func testGitHubReleaseNoPublishedAt() throws {
        let json = """
        {
            "tag_name": "v0.1.0",
            "html_url": "https://github.com/owner/repo",
            "body": "",
            "assets": []
        }
        """.data(using: .utf8)!
        let release = try JSONDecoder().decode(GitHubRelease.self, from: json)
        XCTAssertNil(release.publishedAt)
        XCTAssertTrue(release.assets.isEmpty)
    }

    // MARK: - NetworkError

    func testNetworkErrorDescription() {
        let url = URL(string: "https://example.com/test")!
        let error = NetworkError.requestFailed(url: url)
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("example.com"))
    }

    // MARK: - FileUtilsError

    func testFileUtilsErrorDescriptions() {
        XCTAssertNotNil(FileUtilsError.zipCreationFailed.errorDescription)
        XCTAssertNotNil(FileUtilsError.zipExtractionFailed.errorDescription)
        XCTAssertTrue(FileUtilsError.zipCreationFailed.errorDescription!.contains("ZIP"))
        XCTAssertTrue(FileUtilsError.zipExtractionFailed.errorDescription!.contains("ZIP"))
    }

    // MARK: - FileUtils paths

    func testFileUtilsConfigFilePath() {
        let path = FileUtils.configFilePath(name: "test", format: "toml")
        XCTAssertEqual(path.lastPathComponent, "test.toml")

        let iniPath = FileUtils.configFilePath(name: "test", format: "ini")
        XCTAssertEqual(iniPath.lastPathComponent, "test.ini")
    }

    func testFileUtilsDirectoryPaths() {
        let support = FileUtils.appSupportDirectory()
        XCTAssertTrue(support.path.contains("SwiFRP"))

        let configs = FileUtils.configsDirectory()
        XCTAssertTrue(configs.path.contains("configs"))

        let logs = FileUtils.logsDirectory()
        XCTAssertTrue(logs.path.contains("logs"))
    }
}
