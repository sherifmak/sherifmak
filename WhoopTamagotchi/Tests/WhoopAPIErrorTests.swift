import XCTest
@testable import WhoopTamagotchi

final class WhoopAPIErrorTests: XCTestCase {

    func testErrorDescriptions() {
        XCTAssertNotNil(WhoopAPIError.notAuthenticated.errorDescription)
        XCTAssertNotNil(WhoopAPIError.invalidResponse.errorDescription)
        XCTAssertNotNil(WhoopAPIError.httpError(500).errorDescription)
        XCTAssertNotNil(WhoopAPIError.rateLimited.errorDescription)
    }

    func testHttpErrorIncludesStatusCode() {
        let error = WhoopAPIError.httpError(503)
        XCTAssertTrue(error.errorDescription!.contains("503"))
    }

    // MARK: - Equatable

    func testEqualitySameCase() {
        XCTAssertEqual(WhoopAPIError.notAuthenticated, .notAuthenticated)
        XCTAssertEqual(WhoopAPIError.invalidResponse, .invalidResponse)
        XCTAssertEqual(WhoopAPIError.rateLimited, .rateLimited)
        XCTAssertEqual(WhoopAPIError.httpError(404), .httpError(404))
    }

    func testEqualityDifferentCase() {
        XCTAssertNotEqual(WhoopAPIError.notAuthenticated, .invalidResponse)
        XCTAssertNotEqual(WhoopAPIError.httpError(404), .httpError(500))
        XCTAssertNotEqual(WhoopAPIError.rateLimited, .notAuthenticated)
    }
}
