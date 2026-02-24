import SwiftUI
import SwiftData

struct MealDetailView: View {
    let entry: MealEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @ScaledMetric private var caloriesFontSize: CGFloat = 36

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                imageSection
                caloriesSummary
                NutritionSummaryView(nutrients: NutrientData(from: entry.foodItems))
                foodItemsSection

                if !entry.assumptions.isEmpty {
                    assumptionsSection
                }

                deleteButton
            }
            .padding()
        }
        .navigationTitle(entry.mealType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete Meal",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteMeal()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this meal entry? This action cannot be undone.")
        }
    }

    private var imageSection: some View {
        Group {
            if let imageData = entry.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var caloriesSummary: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: entry.mealType.icon)
                    .foregroundStyle(.green)

                Text(entry.mealType.rawValue)
                    .font(.subheadline)

                Spacer()

                Text(entry.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Calories")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("\(entry.totalCaloriesAvg)")
                        .font(.system(size: caloriesFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                        .accessibilityLabel("\(entry.totalCaloriesAvg) calories")
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Range")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("\(entry.totalCaloriesMin) - \(entry.totalCaloriesMax)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var foodItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Food Items")
                .font(.headline)

            ForEach(entry.foodItems) { food in
                DetailFoodItemRow(food: food)
            }
        }
    }

    private var assumptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Assumptions")
                .font(.headline)

            ForEach(entry.assumptions, id: \.self) { assumption in
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

    private var deleteButton: some View {
        Button(role: .destructive) {
            showingDeleteConfirmation = true
        } label: {
            Label("Delete Meal", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.bordered)
        .tint(.red)
    }

    private func deleteMeal() {
        modelContext.delete(entry)
        try? modelContext.save()
        dismiss()
    }
}

struct DetailFoodItemRow: View {
    let food: FoodItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(food.portionSize)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(confidenceColor)
                        .frame(width: 8, height: 8)

                    Text("\(food.confidenceLevel) confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(food.caloriesAvg)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.green)

                Text("cal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(food.caloriesMin)-\(food.caloriesMax)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var confidenceColor: Color {
        switch food.confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        MealDetailView(entry: MealEntry(
            mealType: .lunch,
            totalCaloriesMin: 400,
            totalCaloriesMax: 500,
            totalCaloriesAvg: 450,
            foodItems: [
                FoodItem(
                    name: "Grilled Chicken",
                    caloriesMin: 200,
                    caloriesMax: 250,
                    caloriesAvg: 225,
                    portionSize: "6 oz",
                    confidence: 0.85
                )
            ],
            assumptions: ["Chicken appears grilled without oil"]
        ))
    }
    .modelContainer(for: MealEntry.self, inMemory: true)
}
