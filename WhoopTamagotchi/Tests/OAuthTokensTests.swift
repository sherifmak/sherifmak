import XCTest
@testable import WhoopTamagotchi

final class OAuthTokensTests: XCTestCase {

    // MARK: - Expiry Detection

    func testTokenNotExpiredWhenFuture() {
        let tokens = OAuthTokens(
            accessToken: "test_access",
            refreshToken: "test_refresh",
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(tokens.isExpired)
    }

    func testTokenExpiredWhenPast() {
        let tokens = OAuthTokens(
            accessToken: "test_access",
            refreshToken: "test_refresh",
            expiresAt: Date().addingTimeInterval(-1)
        )
        XCTAssertTrue(tokens.isExpired)
    }

    func testTokenExpiredWhenExactlyNow() {
        let now = Date()
        let tokens = OAuthTokens(
            accessToken: "test_access",
            refreshToken: "test_refresh",
            expiresAt: now
        )
        // At or past expiresAt should be expired
        XCTAssertTrue(tokens.isExpired)
    }

    // MARK: - Encoding / Decoding

    func testRoundTripWithRefreshToken() throws {
        let tokens = OAuthTokens(
            accessToken: "abc123",
            refreshToken: "refresh456",
            expiresAt: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONEncoder().encode(tokens)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)

        XCTAssertEqual(decoded.accessToken, "abc123")
        XCTAssertEqual(decoded.refreshToken, "refresh456")
        XCTAssertEqual(decoded.expiresAt, Date(timeIntervalSince1970: 1700000000))
    }

    func testRoundTripWithNilRefreshToken() throws {
        let tokens = OAuthTokens(
            accessToken: "abc123",
            refreshToken: nil,
            expiresAt: Date(timeIntervalSince1970: 1700000000)
        )

        let data = try JSONEncoder().encode(tokens)
        let decoded = try JSONDecoder().decode(OAuthTokens.self, from: data)

        XCTAssertEqual(decoded.accessToken, "abc123")
        XCTAssertNil(decoded.refreshToken)
    }
}
