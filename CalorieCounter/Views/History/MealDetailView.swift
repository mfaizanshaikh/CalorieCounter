import SwiftUI
import SwiftData

struct MealDetailView: View {
    let entry: MealEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var editingFood: FoodItem?
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
        .sheet(item: $editingFood) { food in
            FoodItemEditSheet(food: food, entry: entry) {
                // If all food items were deleted, dismiss the detail view too
                if entry.foodItems.isEmpty {
                    dismiss()
                }
            }
        }
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
        MealPhotoView(entry: entry, hero: true)
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
            HStack {
                Text("Food Items")
                    .font(.headline)
                Spacer()
                Text("Tap to edit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(entry.foodItems) { food in
                DetailFoodItemRow(food: food)
                    .contentShape(Rectangle())
                    .onTapGesture { editingFood = food }
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
        SyncStore.delete(meal: entry, in: modelContext)
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

            Image(systemName: "pencil")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.leading, 4)
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

// MARK: - Food Item Edit Sheet

struct FoodItemEditSheet: View {
    let food: FoodItem
    let entry: MealEntry
    let onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var calText: String
    @State private var portionText: String
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var fiberText: String
    @State private var showDeleteConfirm = false

    init(food: FoodItem, entry: MealEntry, onDelete: @escaping () -> Void) {
        self.food = food
        self.entry = entry
        self.onDelete = onDelete
        _calText      = State(initialValue: "\(food.caloriesAvg)")
        _portionText  = State(initialValue: food.portionSize)
        _proteinText  = State(initialValue: food.protein.map  { String(format: "%.1f", $0) } ?? "")
        _carbsText    = State(initialValue: food.carbs.map    { String(format: "%.1f", $0) } ?? "")
        _fatText      = State(initialValue: food.fat.map      { String(format: "%.1f", $0) } ?? "")
        _fiberText    = State(initialValue: food.fiber.map    { String(format: "%.1f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Food") {
                    Text(food.name).font(.headline)
                }

                Section("Serving") {
                    HStack {
                        Text("Portion label")
                        Spacer()
                        TextField("e.g. 150 g", text: $portionText)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Calories") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }

                Section("Macros (optional)") {
                    macroField("Protein (g)", text: $proteinText)
                    macroField("Carbs (g)",   text: $carbsText)
                    macroField("Fat (g)",     text: $fatText)
                    macroField("Fiber (g)",   text: $fiberText)
                }

                Section {
                    Button("Delete Food Item", role: .destructive) {
                        showDeleteConfirm = true
                    }
                }
            }
            .navigationTitle("Edit Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog(
                "Delete Food Item",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { deleteFoodItem() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Remove \(food.name) from this meal?")
            }
        }
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func saveChanges() {
        let newCal = Int(calText) ?? food.caloriesAvg
        food.caloriesMin = newCal
        food.caloriesMax = newCal
        food.caloriesAvg = newCal

        let trimmed = portionText.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { food.portionSize = trimmed }

        food.protein = Double(proteinText)
        food.carbs   = Double(carbsText)
        food.fat     = Double(fatText)
        food.fiber   = Double(fiberText)

        // Recalculate the parent entry's totals
        let total = entry.foodItems.reduce(0) { $0 + $1.caloriesAvg }
        entry.totalCaloriesMin = total
        entry.totalCaloriesMax = total
        entry.totalCaloriesAvg = total

        entry.updatedAt = Date()
        SyncStore.save(meal: entry, in: modelContext)
        dismiss()
    }

    private func deleteFoodItem() {
        entry.foodItems.removeAll { $0.id == food.id }
        modelContext.delete(food)

        let total = entry.foodItems.reduce(0) { $0 + $1.caloriesAvg }
        entry.totalCaloriesMin = total
        entry.totalCaloriesMax = total
        entry.totalCaloriesAvg = total

        if entry.foodItems.isEmpty {
            SyncStore.delete(meal: entry, in: modelContext)
        } else {
            SyncStore.save(meal: entry, in: modelContext)
        }
        dismiss()
        onDelete()
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
