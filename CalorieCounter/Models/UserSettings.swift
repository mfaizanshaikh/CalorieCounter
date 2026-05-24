import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    // MARK: - Keychain Key
    private static let apiKeyKeychainKey = "openai_api_key"
    static let aiDataDisclosureAcceptedKey = "ai_data_disclosure_accepted_v1"

    // Static accessor used by services
    static var openAIAPIKey: String {
        shared.apiKey
    }

    static var hasAcceptedAIDataDisclosure: Bool {
        UserDefaults.standard.bool(forKey: aiDataDisclosureAcceptedKey)
    }

    static func acceptAIDataDisclosure() {
        UserDefaults.standard.set(true, forKey: aiDataDisclosureAcceptedKey)
    }

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let dailyCalorieGoal = "daily_calorie_goal"
        static let showCalorieRange = "show_calorie_range"
        static let hasCompletedOnboarding = "has_completed_onboarding"
    }

    // MARK: - API Key (Keychain-backed)

    var apiKey: String {
        KeychainHelper.load(for: Self.apiKeyKeychainKey) ?? ""
    }

    var hasAPIKey: Bool {
        let key = apiKey
        return !key.isEmpty && key.hasPrefix("sk-")
    }

    var maskedAPIKey: String {
        let key = apiKey
        guard key.count > 8 else { return "Configured" }
        return "sk-...●●●●\(key.suffix(4))"
    }

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainHelper.save(trimmed, for: Self.apiKeyKeychainKey)
        objectWillChange.send()
    }

    func deleteAPIKey() {
        KeychainHelper.delete(for: Self.apiKeyKeychainKey)
        objectWillChange.send()
    }

    // MARK: - Daily Calorie Goal
    @Published var dailyCalorieGoal: Int {
        didSet {
            defaults.set(dailyCalorieGoal, forKey: Keys.dailyCalorieGoal)
            SyncStore.settingsChanged()
        }
    }

    // MARK: - Display Preferences
    @Published var showCalorieRange: Bool {
        didSet {
            defaults.set(showCalorieRange, forKey: Keys.showCalorieRange)
            SyncStore.settingsChanged()
        }
    }

    // MARK: - Onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
            SyncStore.settingsChanged()
        }
    }

    private init() {
        self.dailyCalorieGoal = defaults.object(forKey: Keys.dailyCalorieGoal) as? Int ?? 2000
        self.showCalorieRange = defaults.object(forKey: Keys.showCalorieRange) as? Bool ?? true
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
    }

    // MARK: - Preset Goals
    static let goalPresets: [(name: String, calories: Int)] = [
        ("Weight Loss", 1500),
        ("Moderate Loss", 1750),
        ("Maintenance", 2000),
        ("Moderate Gain", 2250),
        ("Weight Gain", 2500),
        ("Bulking", 3000)
    ]

    func resetToDefaults() {
        dailyCalorieGoal = 2000
        showCalorieRange = true
    }
}
