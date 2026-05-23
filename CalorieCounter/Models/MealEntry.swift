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

    // Sync metadata (added 2026-05-22). All optional / defaulted so SwiftData
    // lightweight migration can populate them for existing 1.2 users.
    var ownerUserId: UUID?
    var updatedAt: Date = Date()
    var deletedAt: Date?
    var photoRemoteId: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType,
        totalCaloriesMin: Int = 0,
        totalCaloriesMax: Int = 0,
        totalCaloriesAvg: Int = 0,
        imageData: Data? = nil,
        foodItems: [FoodItem] = [],
        assumptions: [String] = [],
        ownerUserId: UUID? = nil,
        updatedAt: Date = Date(),
        deletedAt: Date? = nil,
        photoRemoteId: String? = nil
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
        self.ownerUserId = ownerUserId
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.photoRemoteId = photoRemoteId
    }
}

extension MealEntry {
    /// Predicate that scopes a fetch to the currently signed-in user's meals
    /// and hides soft-deleted rows. Pre-migration rows (`ownerUserId == nil`)
    /// are included so users upgrading from v1.2 can still see their meals
    /// during the brief window before first-sign-in migration claims them.
    /// Returns a never-match predicate when no user is provided.
    static func currentUserScope(_ userId: UUID?) -> Predicate<MealEntry> {
        guard let userId else {
            return #Predicate<MealEntry> { _ in false }
        }
        return #Predicate<MealEntry> { meal in
            meal.deletedAt == nil &&
            (meal.ownerUserId == userId || meal.ownerUserId == nil)
        }
    }

    /// Reads the signed-in user's UUID from the keychain. Nonisolated, so it
    /// can be called from SwiftUI view initializers without crossing into
    /// `AuthService`'s MainActor.
    static var currentUserIdFromKeychain: UUID? {
        guard let str = KeychainHelper.load(for: BackendConfig.KeychainKey.userId) else {
            return nil
        }
        return UUID(uuidString: str)
    }

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
