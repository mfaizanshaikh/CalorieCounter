import Foundation
import SwiftData

enum MealType: String, Codable, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    case lateSnack = "Late Snack"

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "fork.knife"
        case .lateSnack: return "moon.stars.fill"
        }
    }
}

@Model
final class MealEntry {
    var id: UUID
    var date: Date
    var mealType: MealType
    var totalCaloriesMin: Int
    var totalCaloriesMax: Int
    var totalCaloriesAvg: Int

    @Attribute(.externalStorage)
    var imageData: Data?

    @Relationship(deleteRule: .cascade)
    var foodItems: [FoodItem]

    var assumptions: [String]

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType,
        totalCaloriesMin: Int = 0,
        totalCaloriesMax: Int = 0,
        totalCaloriesAvg: Int = 0,
        imageData: Data? = nil,
        foodItems: [FoodItem] = [],
        assumptions: [String] = []
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.totalCaloriesMin = totalCaloriesMin
        self.totalCaloriesMax = totalCaloriesMax
        self.totalCaloriesAvg = totalCaloriesAvg
        self.imageData = imageData
        self.foodItems = foodItems
        self.assumptions = assumptions
    }
}

extension MealEntry {
    var calorieRange: String {
        "\(totalCaloriesMin)-\(totalCaloriesMax)"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}
