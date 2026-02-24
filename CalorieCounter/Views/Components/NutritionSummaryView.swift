import SwiftUI

struct NutrientData {
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let saturatedFat: Double?
    let transFat: Double?
    let cholesterol: Double?  // mg
    let sodium: Double?       // mg
    let potassium: Double?    // mg

    var hasData: Bool {
        protein != nil || carbs != nil || fat != nil
    }

    init(from editableFoods: [EditableFoodItem]) {
        func sum(_ keyPath: KeyPath<EditableFoodItem, Double?>) -> Double? {
            let values = editableFoods.compactMap { $0[keyPath: keyPath] }
            return values.isEmpty ? nil : values.reduce(0, +)
        }
        self.protein = sum(\.protein)
        self.carbs = sum(\.carbs)
        self.fat = sum(\.fat)
        self.fiber = sum(\.fiber)
        self.sugar = sum(\.sugar)
        self.saturatedFat = sum(\.saturatedFat)
        self.transFat = sum(\.transFat)
        self.cholesterol = sum(\.cholesterol)
        self.sodium = sum(\.sodium)
        self.potassium = sum(\.potassium)
    }

    init(from foodItems: [FoodItem]) {
        func sum(_ keyPath: KeyPath<FoodItem, Double?>) -> Double? {
            let values = foodItems.compactMap { $0[keyPath: keyPath] }
            return values.isEmpty ? nil : values.reduce(0, +)
        }
        self.protein = sum(\.protein)
        self.carbs = sum(\.carbs)
        self.fat = sum(\.fat)
        self.fiber = sum(\.fiber)
        self.sugar = sum(\.sugar)
        self.saturatedFat = sum(\.saturatedFat)
        self.transFat = sum(\.transFat)
        self.cholesterol = sum(\.cholesterol)
        self.sodium = sum(\.sodium)
        self.potassium = sum(\.potassium)
    }
}

struct NutritionSummaryView: View {
    let nutrients: NutrientData

    var body: some View {
        if nutrients.hasData {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nutrition Facts")
                    .font(.headline)

                VStack(spacing: 0) {
                    // Macronutrients
                    sectionHeader("Macronutrients")
                    nutrientRow("Protein", value: nutrients.protein, unit: "g")
                    nutrientRow("Carbohydrates", value: nutrients.carbs, unit: "g")
                    indentedNutrientRow("Sugar", value: nutrients.sugar, unit: "g")
                    indentedNutrientRow("Fiber", value: nutrients.fiber, unit: "g")
                    nutrientRow("Fat", value: nutrients.fat, unit: "g")
                    indentedNutrientRow("Saturated Fat", value: nutrients.saturatedFat, unit: "g")
                    indentedNutrientRow("Trans Fat", value: nutrients.transFat, unit: "g")

                    // Other Nutrients
                    if nutrients.cholesterol != nil || nutrients.sodium != nil || nutrients.potassium != nil {
                        sectionHeader("Other Nutrients")
                        nutrientRow("Cholesterol", value: nutrients.cholesterol, unit: "mg")
                        nutrientRow("Sodium", value: nutrients.sodium, unit: "mg")
                        nutrientRow("Potassium", value: nutrients.potassium, unit: "mg")
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Nutrition data not available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func nutrientRow(_ name: String, value: Double?, unit: String) -> some View {
        Group {
            if let value {
                HStack {
                    Text(name)
                        .font(.subheadline)
                    Spacer()
                    Text(formatValue(value, unit: unit))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func indentedNutrientRow(_ name: String, value: Double?, unit: String) -> some View {
        Group {
            if let value {
                HStack {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 16)
                    Spacer()
                    Text(formatValue(value, unit: unit))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
                Divider()
            }
        }
    }

    private func formatValue(_ value: Double, unit: String) -> String {
        if value == value.rounded() && value < 1000 {
            return "\(Int(value))\(unit)"
        }
        return String(format: "%.1f%@", value, unit)
    }
}
