import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    private let settings = UserSettings.shared

    var dailyGoal: Int {
        get { settings.dailyCalorieGoal }
        set { settings.dailyCalorieGoal = newValue }
    }

    var showCalorieRange: Bool {
        get { settings.showCalorieRange }
        set { settings.showCalorieRange = newValue }
    }

    var hasAPIKey: Bool {
        settings.hasAPIKey
    }

    func setGoalPreset(_ calories: Int) {
        dailyGoal = calories
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
