import Foundation
import SwiftData

@Model
final class FoodItem {
    var id: UUID
    var name: String
    var caloriesMin: Int
    var caloriesMax: Int
    var caloriesAvg: Int
    var portionSize: String
    var confidence: Double

    // Macro nutrients (optional)
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?

    @Relationship(inverse: \MealEntry.foodItems)
    var mealEntry: MealEntry?

    init(
        id: UUID = UUID(),
        name: String,
        caloriesMin: Int,
        caloriesMax: Int,
        caloriesAvg: Int,
        portionSize: String,
        confidence: Double,
        protein: Double? = nil,
        carbs: Double? = nil,
        fat: Double? = nil,
        fiber: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.caloriesMin = caloriesMin
        self.caloriesMax = caloriesMax
        self.caloriesAvg = caloriesAvg
        self.portionSize = portionSize
        self.confidence = confidence
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
    }
}

extension FoodItem {
    var calorieRange: String {
        "\(caloriesMin)-\(caloriesMax) cal"
    }

    var confidenceLevel: String {
        switch confidence {
        case 0.8...1.0:
            return "High"
        case 0.5..<0.8:
            return "Medium"
        default:
            return "Low"
        }
    }
}
