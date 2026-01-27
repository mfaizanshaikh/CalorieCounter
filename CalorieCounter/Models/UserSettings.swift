import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    private let defaults = UserDefaults.standard

    // Keys
    private enum Keys {
        static let apiKey = "openai_api_key"
        static let dailyCalorieGoal = "daily_calorie_goal"
        static let showCalorieRange = "show_calorie_range"
        static let defaultMealTypeOverride = "default_meal_type_override"
        static let hasCompletedOnboarding = "has_completed_onboarding"
    }

    // MARK: - API Key
    @Published var apiKey: String {
        didSet {
            defaults.set(apiKey, forKey: Keys.apiKey)
        }
    }

    var hasAPIKey: Bool {
        !apiKey.isEmpty
    }

    // MARK: - Daily Calorie Goal
    @Published var dailyCalorieGoal: Int {
        didSet {
            defaults.set(dailyCalorieGoal, forKey: Keys.dailyCalorieGoal)
        }
    }

    // MARK: - Display Preferences
    @Published var showCalorieRange: Bool {
        didSet {
            defaults.set(showCalorieRange, forKey: Keys.showCalorieRange)
        }
    }

    // MARK: - Onboarding
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    private init() {
        // Load saved values or defaults
        self.apiKey = defaults.string(forKey: Keys.apiKey) ?? ""
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
