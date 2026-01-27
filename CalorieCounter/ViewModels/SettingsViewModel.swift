import Foundation
import SwiftUI

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var apiKeyInput: String = ""
    @Published var isAPIKeyVisible: Bool = false
    @Published var showingAPIKeyAlert: Bool = false
    @Published var apiKeyAlertMessage: String = ""
    @Published var isValidatingKey: Bool = false

    private let settings = UserSettings.shared

    init() {
        apiKeyInput = settings.apiKey
    }

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

    var maskedAPIKey: String {
        guard !apiKeyInput.isEmpty else { return "" }
        if apiKeyInput.count <= 8 {
            return String(repeating: "*", count: apiKeyInput.count)
        }
        let prefix = String(apiKeyInput.prefix(4))
        let suffix = String(apiKeyInput.suffix(4))
        return "\(prefix)****\(suffix)"
    }

    func saveAPIKey() {
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.apiKey = trimmedKey
        Task {
            await OpenAIService.shared.setAPIKey(trimmedKey)
        }
    }

    func clearAPIKey() {
        apiKeyInput = ""
        settings.apiKey = ""
        Task {
            await OpenAIService.shared.setAPIKey("")
        }
    }

    func validateAPIKey() async -> Bool {
        isValidatingKey = true
        defer { isValidatingKey = false }

        // Basic format validation
        let trimmedKey = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedKey.isEmpty else {
            apiKeyAlertMessage = "API key cannot be empty"
            showingAPIKeyAlert = true
            return false
        }

        guard trimmedKey.hasPrefix("sk-") else {
            apiKeyAlertMessage = "Invalid API key format. OpenAI keys start with 'sk-'"
            showingAPIKeyAlert = true
            return false
        }

        // Save and show success
        saveAPIKey()
        apiKeyAlertMessage = "API key saved successfully"
        showingAPIKeyAlert = true
        return true
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
