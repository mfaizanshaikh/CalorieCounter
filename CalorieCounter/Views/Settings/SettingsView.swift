import SwiftUI
import SwiftData

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @ObservedObject private var settings = UserSettings.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showingClearDataAlert = false

    var body: some View {
        NavigationStack {
            Form {
                apiKeySection
                calorieGoalSection
                displaySection
                dataSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("API Key", isPresented: $viewModel.showingAPIKeyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.apiKeyAlertMessage)
            }
            .alert("Clear All Data", isPresented: $showingClearDataAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all your meal entries. This action cannot be undone.")
            }
        }
    }

    // MARK: - API Key Section
    private var apiKeySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    if viewModel.isAPIKeyVisible {
                        TextField("sk-...", text: $viewModel.apiKeyInput)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.body, design: .monospaced))
                    } else {
                        SecureField("sk-...", text: $viewModel.apiKeyInput)
                            .textContentType(.password)
                            .autocapitalization(.none)
                            .font(.system(.body, design: .monospaced))
                    }

                    Button {
                        viewModel.isAPIKeyVisible.toggle()
                    } label: {
                        Image(systemName: viewModel.isAPIKeyVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await viewModel.validateAPIKey()
                        }
                    } label: {
                        if viewModel.isValidatingKey {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Save Key")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(viewModel.apiKeyInput.isEmpty || viewModel.isValidatingKey)

                    if viewModel.hasAPIKey {
                        Button("Clear", role: .destructive) {
                            viewModel.clearAPIKey()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.vertical, 4)

            if viewModel.hasAPIKey {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("API key configured")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("OpenAI API Key")
        } footer: {
            Text("Required for food analysis. Get your API key from platform.openai.com")
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

                // Quick presets
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
                    Text("Clear All Meal Data")
                }
            }
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

            Link(destination: URL(string: "https://platform.openai.com/docs")!) {
                HStack {
                    Text("OpenAI Documentation")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Actions
    private func clearAllData() {
        do {
            try modelContext.delete(model: MealEntry.self)
            try modelContext.delete(model: FoodItem.self)
        } catch {
            print("Failed to clear data: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: MealEntry.self, inMemory: true)
}
