import SwiftUI
import SwiftData

struct AnalysisView: View {
    let image: UIImage
    @ObservedObject var viewModel: AnalysisViewModel
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var showingSaveSuccess = false
    @FocusState private var isCalorieFieldFocused: Bool
    @ScaledMetric private var caloriesFontSize: CGFloat = 48

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                imageSection

                if viewModel.isAnalyzing {
                    analyzingSection
                } else if let result = viewModel.analysisResult {
                    resultSection(result)
                } else if let error = viewModel.errorMessage {
                    errorSection(error)
                }
            }
            .padding()
        }
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isAnalyzing)
        .toolbar {
            if !viewModel.isAnalyzing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .alert("Meal Saved!", isPresented: $showingSaveSuccess) {
            Button("OK") {
                onDismiss()
            }
        } message: {
            Text("Your meal has been logged successfully.")
        }
    }

    private var imageSection: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var analyzingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing your food...")
                .font(.headline)

            Text("This may take a moment")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func resultSection(_ result: CalorieEstimation) -> some View {
        VStack(spacing: 20) {
            if result.status == .noFoodDetected {
                noFoodDetectedView
            } else {
                foodDetectedView(result)
            }
        }
    }

    private var noFoodDetectedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("No Food Detected")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We couldn't identify any food in this image. Please try another photo.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }

    private func foodDetectedView(_ result: CalorieEstimation) -> some View {
        VStack(spacing: 20) {
            totalCaloriesCard(result)
            NutritionSummaryView(nutrients: NutrientData(from: viewModel.editableFoods))
            mealTypeSelector
            editableFoodItemsList

            if !result.assumptions.isEmpty {
                assumptionsSection(result.assumptions)
            }

            saveButton
        }
    }

    private func totalCaloriesCard(_ result: CalorieEstimation) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Total Calories")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if viewModel.hasEdits {
                    Text("(edited)")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Editable calorie input
            HStack(spacing: 8) {
                TextField("", value: $viewModel.userEditedTotalCalories, format: .number)
                    .keyboardType(.numberPad)
                    .font(.system(size: caloriesFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(viewModel.hasEdits ? .orange : .green)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 180)
                    .focused($isCalorieFieldFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                isCalorieFieldFocused = false
                            }
                        }
                    }

                Text("cal")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }

            // Slider for adjusting calories
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(viewModel.userEditedTotalCalories) },
                        set: { viewModel.userEditedTotalCalories = Int($0) }
                    ),
                    in: viewModel.sliderMin...viewModel.sliderMax,
                    step: 10
                )
                .tint(viewModel.hasEdits ? .orange : .green)

                HStack {
                    Text("\(Int(viewModel.sliderMin))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(Int(viewModel.sliderMax))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 4)

            if !viewModel.hasEdits {
                Text("\(result.totalCaloriesMin) - \(result.totalCaloriesMax) cal range")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button {
                    viewModel.resetAllToOriginal()
                } label: {
                    Label("Reset to original (\(viewModel.originalTotalCalories) cal)", systemImage: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mealTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Meal Type")
                .font(.headline)

            Picker("Meal Type", selection: $viewModel.selectedMealType) {
                ForEach(MealType.allCases, id: \.self) { type in
                    Label(type.rawValue, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var editableFoodItemsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Foods")
                .font(.headline)

            ForEach(viewModel.editableFoods) { food in
                ReadonlyFoodItemRow(food: food)
            }
        }
    }

    private func assumptionsSection(_ assumptions: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assumptions Made")
                .font(.headline)

            ForEach(assumptions, id: \.self) { assumption in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text(assumption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var saveButton: some View {
        Button {
            if viewModel.saveMealEntry(image: image, to: modelContext) != nil {
                showingSaveSuccess = true
            }
        } label: {
            Label("Save Meal", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private func errorSection(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Analysis Failed")
                .font(.title2)
                .fontWeight(.semibold)

            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if error.contains("Daily limit") {
                Text("You've reached the daily limit. Add your own API key in Settings for unlimited usage.")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 4)
            }

            Button("Try Again") {
                Task {
                    await viewModel.analyzeImage(image)
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
    }
}

struct ReadonlyFoodItemRow: View {
    let food: EditableFoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(food.portionSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    Text("\(food.originalAvg)")
                        .font(.body)
                        .fontWeight(.semibold)

                    Text("cal")
                        .font(.body)
                }
                .foregroundStyle(.green)

                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)

                    Text(confidenceLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(food.name), \(food.portionSize), \(food.originalAvg) calories, \(confidenceLabel) confidence")
    }

    private var confidenceColor: Color {
        switch food.confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }

    private var confidenceLabel: String {
        switch food.confidence {
        case 0.8...1.0: return "High"
        case 0.5..<0.8: return "Medium"
        default: return "Low"
        }
    }
}

#Preview {
    NavigationStack {
        AnalysisView(
            image: UIImage(systemName: "photo")!,
            viewModel: AnalysisViewModel(),
            onDismiss: {}
        )
    }
    .modelContainer(for: MealEntry.self, inMemory: true)
}
