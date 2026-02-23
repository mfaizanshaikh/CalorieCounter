import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    private let settings = UserSettings.shared

    // MARK: - API Key
    @Published var apiKeyInput: String = ""

    var hasAPIKey: Bool {
        settings.hasAPIKey
    }

    var maskedAPIKey: String {
        settings.maskedAPIKey
    }

    func saveAPIKey() {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.saveAPIKey(trimmed)
        apiKeyInput = ""
        objectWillChange.send()
    }

    func removeAPIKey() {
        settings.deleteAPIKey()
        objectWillChange.send()
    }

    // MARK: - Calorie Goal
    var dailyGoal: Int {
        get { settings.dailyCalorieGoal }
        set { settings.dailyCalorieGoal = newValue }
    }

    var showCalorieRange: Bool {
        get { settings.showCalorieRange }
        set { settings.showCalorieRange = newValue }
    }

    func setGoalPreset(_ calories: Int) {
        dailyGoal = calories
    }

    // MARK: - App Info
    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}
