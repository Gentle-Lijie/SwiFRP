import XCTest
@testable import SwiFRP

final class SwiFRPTests: XCTestCase {
    func testAppTabCases() {
        XCTAssertEqual(AppTab.allCases.count, 4)
    }

    func testAppConfigDefaults() {
        let config = AppConfig()
        XCTAssertTrue(config.password.isEmpty)
        XCTAssertTrue(config.sort.isEmpty)
        XCTAssertFalse(config.autoStart)
    }

    func testClientConfigIdentifiable() {
        let config = ClientConfig(name: "test")
        XCTAssertEqual(config.id, "test")
        XCTAssertEqual(config.serverPort, 7000)
    }
}
