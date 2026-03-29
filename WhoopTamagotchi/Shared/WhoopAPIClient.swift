import Foundation

final class WhoopAPIClient {
    static let shared = WhoopAPIClient()

    // MARK: - Configuration
    // Register your app at https://developer.whoop.com to get these
    static var clientId: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "WHOOP_CLIENT_ID") as? String,
              !value.isEmpty else {
            assertionFailure("WHOOP_CLIENT_ID not configured. See Config.xcconfig.example.")
            return ""
        }
        return value
    }

    static var clientSecret: String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "WHOOP_CLIENT_SECRET") as? String,
              !value.isEmpty else {
            assertionFailure("WHOOP_CLIENT_SECRET not configured. See Config.xcconfig.example.")
            return ""
        }
        return value
    }

    static let redirectURI = "whooptamagotchi://oauth/callback"
    static let baseURL = "https://api.prod.whoop.com/developer/v2"
    static let authURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
    static let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    static let scopes = "read:cycles offline"

    private let session: URLSession
    private static let requestTimeout: TimeInterval = 15

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = Self.requestTimeout
        config.timeoutIntervalForResource = 30
        session = URLSession(configuration: config)
    }

    // MARK: - OAuth Authorization URL

    func authorizationURL(state: String) -> URL? {
        var components = URLComponents(string: Self.authURL)
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientId),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "state", value: state)
        ]
        return components?.url
    }

    // MARK: - Token Exchange

    func exchangeCodeForTokens(code: String) async throws -> OAuthTokens {
        guard let url = URL(string: Self.tokenURL) else {
            throw WhoopAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "authorization_code",
            "code": code,
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret,
            "redirect_uri": Self.redirectURI
        ]
        request.httpBody = params.urlEncodedBody

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        let tokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
        try tokens.save()
        return tokens
    }

    // MARK: - Token Refresh

    func refreshTokens() async throws -> OAuthTokens {
        guard let current = OAuthTokens.load(), let refreshToken = current.refreshToken else {
            throw WhoopAPIError.notAuthenticated
        }

        guard let url = URL(string: Self.tokenURL) else {
            throw WhoopAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": Self.clientId,
            "client_secret": Self.clientSecret
        ]
        request.httpBody = params.urlEncodedBody

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        let tokens = OAuthTokens(
            accessToken: tokenResponse.accessToken,
            refreshToken: tokenResponse.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenResponse.expiresIn))
        )
        try tokens.save()
        return tokens
    }

    // MARK: - Fetch Today's Strain (v2 API)

    func fetchTodayStrain() async throws -> Double {
        let tokens = try await validTokens()

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let startParam = ISO8601DateFormatter().string(from: startOfDay)

        guard var components = URLComponents(string: "\(Self.baseURL)/cycle") else {
            throw WhoopAPIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "start", value: startParam),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else {
            throw WhoopAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateHTTPResponse(response)

        let cycleResponse = try JSONDecoder().decode(CycleResponse.self, from: data)

        guard let cycle = cycleResponse.records.first,
              cycle.scoreState == "SCORED",
              let score = cycle.score else {
            return 0.0
        }

        let state = TamagotchiState(
            strain: score.strain,
            strainLevel: StrainLevel.from(strain: score.strain),
            lastUpdated: Date()
        )
        state.save()

        return score.strain
    }

    // MARK: - Helpers

    private func validTokens() async throws -> OAuthTokens {
        guard var tokens = OAuthTokens.load() else {
            markNeedsReauth()
            throw WhoopAPIError.notAuthenticated
        }
        if tokens.isExpired {
            do {
                tokens = try await refreshTokens()
            } catch {
                markNeedsReauth()
                throw error
            }
        }
        return tokens
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAPIError.invalidResponse
        }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            markNeedsReauth()
            throw WhoopAPIError.notAuthenticated
        case 429:
            throw WhoopAPIError.rateLimited
        default:
            throw WhoopAPIError.httpError(httpResponse.statusCode)
        }
    }

    private func markNeedsReauth() {
        let state = TamagotchiState(
            strain: TamagotchiState.load()?.strain ?? 0,
            strainLevel: TamagotchiState.load()?.strainLevel ?? .resting,
            lastUpdated: TamagotchiState.load()?.lastUpdated ?? Date(),
            needsReauth: true
        )
        state.save()
    }
}

// MARK: - Supporting Types

private struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
    }
}

enum WhoopAPIError: Error, LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(Int)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not logged in to WHOOP. Open the app to sign in."
        case .invalidResponse:
            return "Received an invalid response from WHOOP."
        case .httpError(let code):
            return "WHOOP API error (HTTP \(code))."
        case .rateLimited:
            return "Too many requests. Please try again later."
        }
    }
}

// MARK: - URL Encoding Helper

private extension Dictionary where Key == String, Value == String {
    var urlEncodedBody: Data? {
        map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }
        .joined(separator: "&")
        .data(using: .utf8)
    }
}
