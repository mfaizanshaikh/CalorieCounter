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
    var sugar: Double?
    var saturatedFat: Double?
    var transFat: Double?
    var cholesterol: Double?  // mg
    var sodium: Double?       // mg
    var potassium: Double?    // mg

    @Relationship(inverse: \MealEntry.foodItems)
    var mealEntry: MealEntry?

    // Sync metadata (added 2026-05-22).
    var updatedAt: Date = Date()
    var deletedAt: Date?

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
        fiber: Double? = nil,
        sugar: Double? = nil,
        saturatedFat: Double? = nil,
        transFat: Double? = nil,
        cholesterol: Double? = nil,
        sodium: Double? = nil,
        potassium: Double? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
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
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.transFat = transFat
        self.cholesterol = cholesterol
        self.sodium = sodium
        self.potassium = potassium
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
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
