import Foundation

// MARK: - WHOOP API Response Models

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
    let start: String
    let end: String?
    let scoreState: String
    let score: CycleScore?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case start
        case end
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

// MARK: - Strain Level Mapping

enum StrainLevel: String, CaseIterable {
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

    var emoji: String {
        switch self {
        case .resting:   return "😴"
        case .light:     return "😊"
        case .moderate:  return "💪"
        case .high:      return "😤"
        case .overreach: return "🥵"
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

    var color: String {
        switch self {
        case .resting:   return "tamagotchiBlue"
        case .light:     return "tamagotchiGreen"
        case .moderate:  return "tamagotchiYellow"
        case .high:      return "tamagotchiOrange"
        case .overreach: return "tamagotchiRed"
        }
    }
}

// MARK: - Shared Data Store

struct TamagotchiState: Codable {
    let strain: Double
    let strainLevel: String
    let lastUpdated: Date

    static let suiteName = "group.com.whooptamagotchi.shared"
    static let stateKey = "tamagotchi_state"

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

// MARK: - OAuth Token Storage

struct OAuthTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }

    static let keychainService = "com.whooptamagotchi.tokens"
    static let keychainAccount = "whoop_oauth"

    func save() throws {
        let data = try JSONEncoder().encode(self)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecAttrAccessGroup as String: "group.com.whooptamagotchi.shared"
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func load() -> OAuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessGroup as String: "group.com.whooptamagotchi.shared",
            kSecReturnData as String: true
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(OAuthTokens.self, from: data)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum KeychainError: Error {
    case saveFailed(OSStatus)
}
