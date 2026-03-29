import Foundation
import Security

// MARK: - WHOOP API v2 Response Models

struct CycleResponse: Codable {
    let records: [WhoopCycle]
    let nextToken: String?

    enum CodingKeys: String, CodingKey {
        case records
        case nextToken = "next_token"
    }
}

struct WhoopCycle: Codable {
    let id: Int
    let userId: Int
    let createdAt: String
    let updatedAt: String
    let start: String
    let end: String?
    let timezoneOffset: String?
    let scoreState: String
    let score: CycleScore?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case start
        case end
        case timezoneOffset = "timezone_offset"
        case scoreState = "score_state"
        case score
    }
}

struct CycleScore: Codable {
    let strain: Double
    let kilojoule: Double
    let averageHeartRate: Int
    let maxHeartRate: Int

    enum CodingKeys: String, CodingKey {
        case strain
        case kilojoule
        case averageHeartRate = "average_heart_rate"
        case maxHeartRate = "max_heart_rate"
    }
}

// MARK: - Webhook Payload Models

struct WebhookEvent: Codable {
    let type: String
    let userId: Int
    let id: Int
    let timestamp: String

    enum CodingKeys: String, CodingKey {
        case type
        case userId = "user_id"
        case id
        case timestamp
    }
}

// MARK: - Strain Level Mapping

enum StrainLevel: String, CaseIterable, Codable {
    case resting    // 0-4: Chilling, barely moved
    case light      // 4-8: Easy day, light activity
    case moderate   // 8-13: Solid effort
    case high       // 13-17: Pushing hard
    case overreach  // 17-21: All out, max effort

    static func from(strain: Double) -> StrainLevel {
        switch strain {
        case 0..<4:    return .resting
        case 4..<8:    return .light
        case 8..<13:   return .moderate
        case 13..<17:  return .high
        default:       return .overreach
        }
    }

    var label: String {
        switch self {
        case .resting:   return "Chilling"
        case .light:     return "Easy Day"
        case .moderate:  return "Solid Work"
        case .high:      return "Pushing It"
        case .overreach: return "All Out"
        }
    }
}

// MARK: - Shared Data Store (App Group UserDefaults)

struct TamagotchiState: Codable {
    let strain: Double
    let strainLevel: StrainLevel
    let lastUpdated: Date
    let needsReauth: Bool

    static let suiteName = "group.com.whooptamagotchi.shared"
    static let stateKey = "tamagotchi_state"

    init(strain: Double, strainLevel: StrainLevel, lastUpdated: Date, needsReauth: Bool = false) {
        self.strain = strain
        self.strainLevel = strainLevel
        self.lastUpdated = lastUpdated
        self.needsReauth = needsReauth
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: Self.suiteName) else { return }
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }

    static func load() -> TamagotchiState? {
        guard let defaults = UserDefaults(suiteName: Self.suiteName),
              let data = defaults.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(TamagotchiState.self, from: data) else {
            return nil
        }
        return state
    }
}

// MARK: - OAuth Token Storage (Shared Keychain)

struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    private static let keychainService = "com.whooptamagotchi.tokens"
    private static let keychainAccount = "whoop_oauth"
    private static let accessGroup = "group.com.whooptamagotchi.shared"

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: accessGroup
        ]
    }

    func save() throws {
        let data = try JSONEncoder().encode(self)

        // Delete existing item first
        SecItemDelete(Self.baseQuery as CFDictionary)

        var query = Self.baseQuery
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() -> OAuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
