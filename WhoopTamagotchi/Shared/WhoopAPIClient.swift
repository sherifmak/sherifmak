import Foundation

final class WhoopAPIClient {
    static let shared = WhoopAPIClient()

    // MARK: - Configuration
    // Register your app at https://developer.whoop.com to get these
    static var clientId: String {
        Bundle.main.object(forInfoDictionaryKey: "WHOOP_CLIENT_ID") as? String ?? ""
    }
    static var clientSecret: String {
        Bundle.main.object(forInfoDictionaryKey: "WHOOP_CLIENT_SECRET") as? String ?? ""
    }
    static let redirectURI = "whooptamagotchi://oauth/callback"
    static let baseURL = "https://api.prod.whoop.com/developer/v1"
    static let authURL = "https://api.prod.whoop.com/oauth/oauth2/auth"
    static let tokenURL = "https://api.prod.whoop.com/oauth/oauth2/token"
    static let scopes = "read:cycles offline"

    private init() {}

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
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=authorization_code",
            "code=\(code)",
            "client_id=\(Self.clientId)",
            "client_secret=\(Self.clientSecret)",
            "redirect_uri=\(Self.redirectURI)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        let tokens = OAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        try tokens.save()
        return tokens
    }

    // MARK: - Token Refresh

    func refreshTokens() async throws -> OAuthTokens {
        guard let current = OAuthTokens.load(), let refreshToken = current.refreshToken else {
            throw WhoopAPIError.notAuthenticated
        }

        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(Self.clientId)",
            "client_secret=\(Self.clientSecret)"
        ].joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(TokenResponse.self, from: data)

        let tokens = OAuthTokens(
            accessToken: response.accessToken,
            refreshToken: response.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(response.expiresIn))
        )
        try tokens.save()
        return tokens
    }

    // MARK: - Fetch Today's Strain

    func fetchTodayStrain() async throws -> Double {
        let tokens = try await validTokens()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let formatter = ISO8601DateFormatter()
        let startParam = formatter.string(from: startOfDay)

        var components = URLComponents(string: "\(Self.baseURL)/cycle")!
        components.queryItems = [
            URLQueryItem(name: "start", value: startParam),
            URLQueryItem(name: "limit", value: "1")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhoopAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw WhoopAPIError.notAuthenticated
            }
            throw WhoopAPIError.httpError(httpResponse.statusCode)
        }

        let cycleResponse = try JSONDecoder().decode(CycleResponse.self, from: data)

        guard let cycle = cycleResponse.records.first,
              cycle.scoreState == "SCORED",
              let score = cycle.score else {
            return 0.0 // No scored cycle yet today
        }

        // Persist for widget access
        let state = TamagotchiState(
            strain: score.strain,
            strainLevel: StrainLevel.from(strain: score.strain).rawValue,
            lastUpdated: Date()
        )
        state.save()

        return score.strain
    }

    // MARK: - Helpers

    private func validTokens() async throws -> OAuthTokens {
        guard var tokens = OAuthTokens.load() else {
            throw WhoopAPIError.notAuthenticated
        }
        if tokens.isExpired {
            tokens = try await refreshTokens()
        }
        return tokens
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

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not logged in to WHOOP. Open the app to sign in."
        case .invalidResponse:
            return "Received an invalid response from WHOOP."
        case .httpError(let code):
            return "WHOOP API error (HTTP \(code))."
        }
    }
}
