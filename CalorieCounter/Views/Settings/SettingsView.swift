import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearDataAlert = false
    @State private var showingRemoveKeyAlert = false

    var body: some View {
        NavigationStack {
            Form {
                AccountSection()
                calorieGoalSection
                displaySection
                dataSection
                apiKeySection
                AccountActionsSection()
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your meal entries and remove any public wall posts based on those meals. This action cannot be undone.")
            }
            .alert("Remove API Key", isPresented: $showingRemoveKeyAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Remove", role: .destructive) {
                    viewModel.removeAPIKey()
                }
            } message: {
                Text("This will remove your custom API key. The app will switch back to the built-in service.")
            }
        }
    }

    // MARK: - API Key Section (Optional — for users who want their own key)
    private var apiKeySection: some View {
        Section {
            if viewModel.hasAPIKey {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Using Your Own API Key")
                            .font(.body)
                        Text(viewModel.maskedAPIKey)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Remove") {
                        showingRemoveKeyAlert = true
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Remove OpenAI API key")
                }
            } else {
                HStack {
                    SecureField("Paste your OpenAI key (sk-...)", text: $viewModel.apiKeyInput)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .accessibilityLabel("OpenAI API key input")

                    Button("Save") {
                        viewModel.saveAPIKey()
                    }
                    .disabled(viewModel.apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Save API key")
                }
            }
        } header: {
            Text("Custom API Key (Optional)")
        } footer: {
            if viewModel.hasAPIKey {
                Text("Using your own OpenAI API key. Remove it to switch back to the built-in service.")
            } else {
                Text("AI food analysis works out of the box. Optionally add your own OpenAI API key for unlimited usage.")
            }
        }
    }

    // MARK: - Calorie Goal Section
    private var calorieGoalSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Daily Goal")
                    Spacer()
                    Text("\(settings.dailyCalorieGoal) cal")
                        .font(.headline)
                        .foregroundStyle(.green)
                }

                Slider(
                    value: Binding(
                        get: { Double(settings.dailyCalorieGoal) },
                        set: { settings.dailyCalorieGoal = Int($0) }
                    ),
                    in: 1000...4000,
                    step: 50
                )
                .tint(.green)
                .accessibilityLabel("Daily calorie goal slider")
                .accessibilityValue("\(settings.dailyCalorieGoal) calories")

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Presets")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(UserSettings.goalPresets, id: \.calories) { preset in
                            Button {
                                withAnimation {
                                    settings.dailyCalorieGoal = preset.calories
                                }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(preset.name)
                                        .font(.caption)
                                    Text("\(preset.calories)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    settings.dailyCalorieGoal == preset.calories
                                        ? Color.green.opacity(0.2)
                                        : Color(.systemGray5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(preset.name), \(preset.calories) calories")
                            .accessibilityAddTraits(settings.dailyCalorieGoal == preset.calories ? .isSelected : [])
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Calorie Goal")
        } footer: {
            Text("Set your daily calorie target based on your fitness goals")
        }
    }

    // MARK: - Display Section
    private var displaySection: some View {
        Section {
            Toggle("Show Calorie Range", isOn: $settings.showCalorieRange)
                .accessibilityLabel("Show calorie range toggle")
        } header: {
            Text("Display")
        } footer: {
            Text("Show min-max calorie range in addition to average")
        }
    }

    // MARK: - Data Section
    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                showingClearDataAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                        .accessibilityHidden(true)
                    Text("Clear All Meal Data")
                }
            }
            .accessibilityLabel("Clear all meal data")
            .accessibilityHint("Permanently deletes all meal entries")
        } header: {
            Text("Data")
        }
    }

    // MARK: - About Section
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(viewModel.appVersion)
                    .foregroundStyle(.secondary)
            }
            Link(destination: URL(string: "https://mfaizanshaikh.wordpress.com/2026/02/27/privacy-policy-ai-calorie-coach/")!) {
                HStack {
                    Text("Privacy Policy")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Privacy Policy — opens in browser")
            Link(destination: URL(string: "mailto:mfaizan.shaikh@gmail.com")!) {
                HStack {
                    Text("Contact Support")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel("Contact support by email")
        } header: {
            Text("About")
        } footer: {
            Text("This app sends food photos to OpenAI to estimate nutritional content. Wall posts are public only when you tap Post to Wall.")
        }
    }

    // MARK: - Actions
    private func clearAllData() {
        // Queue server-side deletes for each meal so cloud data stays in sync.
        SyncStore.deleteAllMeals(in: modelContext)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
