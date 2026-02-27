import Foundation
import SwiftData

@Model
final class SavedFood {
    var id: UUID
    var name: String
    var caloriesPer100g: Double
    var proteinPer100g: Double?
    var carbsPer100g: Double?
    var fatPer100g: Double?
    var fiberPer100g: Double?
    var sodiumPer100g: Double?
    var defaultServingSizeG: Double
    var defaultServingLabel: String

    /// Times the user has actually added this food to a meal — used for "Frequent" sorting.
    var searchCount: Int

    /// true = sourced from AI search; false = from bundled JSON or user history
    var isFromAI: Bool

    var dateAdded: Date

    init(
        id: UUID = UUID(),
        name: String,
        caloriesPer100g: Double,
        proteinPer100g: Double? = nil,
        carbsPer100g: Double? = nil,
        fatPer100g: Double? = nil,
        fiberPer100g: Double? = nil,
        sodiumPer100g: Double? = nil,
        defaultServingSizeG: Double = 100,
        defaultServingLabel: String = "100 g",
        searchCount: Int = 0,
        isFromAI: Bool = false,
        dateAdded: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.caloriesPer100g = caloriesPer100g
        self.proteinPer100g = proteinPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.sodiumPer100g = sodiumPer100g
        self.defaultServingSizeG = defaultServingSizeG
        self.defaultServingLabel = defaultServingLabel
        self.searchCount = searchCount
        self.isFromAI = isFromAI
        self.dateAdded = dateAdded
    }
}

// MARK: - Conversion to FoodSearchResult

extension FoodSearchResult {
    init(from saved: SavedFood) {
        self.init(
            id: saved.id,
            name: saved.name,
            caloriesPer100g: saved.caloriesPer100g,
            proteinPer100g: saved.proteinPer100g,
            carbsPer100g: saved.carbsPer100g,
            fatPer100g: saved.fatPer100g,
            fiberPer100g: saved.fiberPer100g,
            sodiumPer100g: saved.sodiumPer100g,
            defaultServingSizeG: saved.defaultServingSizeG,
            defaultServingLabel: saved.defaultServingLabel,
            source: saved.isFromAI ? .ai : .local
        )
    }
}
