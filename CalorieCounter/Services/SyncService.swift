import Foundation
import SwiftData
import UIKit

/// Push/pull primitives. Stateless re: SwiftUI — the coordinator drives it.
/// All work happens on a private ModelContext to avoid blocking the main thread.
actor SyncService {
    static let shared = SyncService()

    private let api: APIClient
    private init(api: APIClient = .shared) { self.api = api }

    private static let lastPushedAtKey = "sync.lastPushedAt.v1"
    private static let lastPulledAtKey = "sync.lastPulledAt.v1"
    private static let migrationDoneKey = "sync.migration_v1_done"

    // MARK: - Public entry points

    /// Push dirty (modified-since-last-push) records to the server.
    func flush(using container: ModelContainer, ownerUserId: UUID) async throws {
        let context = ModelContext(container)
        let cutoff = (UserDefaults.standard.object(forKey: Self.lastPushedAtKey) as? Date) ?? .distantPast
        let now = Date()

        try await drainSyncOps(context: context)
        try await pushMeals(context: context, ownerUserId: ownerUserId, since: cutoff)
        try await pushSavedFoods(context: context, ownerUserId: ownerUserId, since: cutoff)
        try await pushSettings(ownerUserId: ownerUserId)

        UserDefaults.standard.set(now, forKey: Self.lastPushedAtKey)
    }

    /// Drain the SyncOp queue. Today this is used only for deletes (since
    /// upserts are timestamp-driven). Failed ops stay in the queue with their
    /// `attempts` incremented; the next flush retries after the backoff window.
    private func drainSyncOps(context: ModelContext) async throws {
        let now = Date()
        let descriptor = FetchDescriptor<SyncOp>(
            predicate: #Predicate { $0.nextAttemptAt <= now }
        )
        let ops = try context.fetch(descriptor)
        for op in ops {
            do {
                switch (op.entityType, op.opType) {
                case (.meal, .delete):
                    try await api.delete("meals/\(op.entityId.uuidString)")
                case (.savedFood, .delete):
                    try await api.delete("saved-foods/\(op.entityId.uuidString)")
                case (.foodItem, .delete):
                    try await api.delete("food-items/\(op.entityId.uuidString)")
                case (.photo, .delete):
                    try await api.delete("photos/\(op.entityId.uuidString)")
                default:
                    // Other op types not used today.
                    break
                }
                context.delete(op)
            } catch {
                op.attempts += 1
                op.lastError = error.localizedDescription
                op.nextAttemptAt = Date().addingTimeInterval(min(60 * pow(2.0, Double(op.attempts)), 600))
                // Give up after 8 attempts to avoid infinite retries.
                if op.attempts >= 8 { context.delete(op) }
            }
        }
        try context.save()
    }

    /// Pull server state newer than our last pull and merge into the local store.
    func pull(using container: ModelContainer, ownerUserId: UUID) async throws {
        let since = (UserDefaults.standard.object(forKey: Self.lastPulledAtKey) as? Date) ?? .distantPast
        let isoFormatter = ISO8601DateFormatter()
        let response: SyncStateResponse = try await api.get(
            "sync/state",
            query: ["since": isoFormatter.string(from: since)]
        )
        let context = ModelContext(container)
        try await applyMerge(response, ownerUserId: ownerUserId, context: context)
        // Use the server's clock for the next "since" cutoff so client/server
        // skew doesn't silently drop records updated during the request window.
        let nextSince = response.serverTime ?? Date()
        UserDefaults.standard.set(nextSince, forKey: Self.lastPulledAtKey)
    }

    /// First-sign-in: take all local data that doesn't have an owner, claim it
    /// for `userId`, push it in one bulk multipart request, and mark done.
    func runMigrationIfNeeded(using container: ModelContainer, ownerUserId: UUID) async throws {
        if UserDefaults.standard.bool(forKey: Self.migrationDoneKey) { return }
        let context = ModelContext(container)

        // Claim ownership for any pre-account local rows.
        let meals = try context.fetch(FetchDescriptor<MealEntry>())
        let savedFoods = try context.fetch(FetchDescriptor<SavedFood>())

        let nowStamp = Date()
        var claimedMealCount = 0
        var claimedFoodCount = 0
        for meal in meals where meal.ownerUserId == nil {
            meal.ownerUserId = ownerUserId
            meal.updatedAt = nowStamp
            claimedMealCount += 1
        }
        for food in savedFoods where food.ownerUserId == nil && (food.isFromAI || food.searchCount > 0) {
            food.ownerUserId = ownerUserId
            food.updatedAt = nowStamp
            claimedFoodCount += 1
        }
        try context.save()

        // Drop the "since" cutoff so flush() picks everything up.
        UserDefaults.standard.set(Date.distantPast, forKey: Self.lastPushedAtKey)
        try await flush(using: container, ownerUserId: ownerUserId)
        UserDefaults.standard.set(true, forKey: Self.migrationDoneKey)

        #if DEBUG
        print("[Sync] Migration done: \(claimedMealCount) meals, \(claimedFoodCount) saved foods")
        #endif
    }

    // MARK: - Push helpers

    private func pushMeals(context: ModelContext, ownerUserId: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { meal in
                meal.updatedAt > since
            }
        )
        let dirty = try context.fetch(descriptor)
        for meal in dirty where meal.ownerUserId == ownerUserId || meal.ownerUserId == nil {
            if meal.ownerUserId == nil { meal.ownerUserId = ownerUserId }
            try await pushMeal(meal, context: context)
            // Persist per-meal so a later failure doesn't lose owner-claim
            // and photoRemoteId bookkeeping for meals already pushed.
            try? context.save()
        }
    }

    private func pushMeal(_ meal: MealEntry, context: ModelContext) async throws {
        // 1. Upload photo first if it's a new image we haven't synced yet.
        if let imageData = meal.imageData, meal.photoRemoteId == nil, meal.deletedAt == nil {
            struct PhotoRes: Decodable { let id: String }
            let res: PhotoRes = try await api.upload(
                "photos",
                jsonPart: PhotoMeta(mealId: meal.id),
                files: [(name: "photo", filename: "\(meal.id).jpg", mimeType: "image/jpeg", data: imageData)]
            )
            meal.photoRemoteId = res.id
            // Persist immediately so a failure in step 2 doesn't cause the
            // next flush to upload the same photo again (leaving an orphan
            // file on the server). The JSON envelope below will still be
            // re-sent on retry because the meal's updatedAt is unchanged.
            try? context.save()
        }

        // 2. Push the JSON envelope.
        let dto = MealDTO(from: meal)
        if meal.deletedAt != nil {
            try await api.delete("meals/\(meal.id.uuidString)")
            // Physically delete after server confirms.
            context.delete(meal)
            try? context.save()
        } else {
            _ = try await api.post("meals", body: dto) as EmptyResponse
        }
    }

    private func pushSavedFoods(context: ModelContext, ownerUserId: UUID, since: Date) async throws {
        let descriptor = FetchDescriptor<SavedFood>(
            predicate: #Predicate { food in
                food.updatedAt > since
            }
        )
        let dirty = try context.fetch(descriptor)
        for food in dirty {
            // Skip bundled foods (no owner, not from AI, no search count) — they re-seed locally.
            if food.ownerUserId == nil && !food.isFromAI && food.searchCount == 0 { continue }
            if food.ownerUserId == nil { food.ownerUserId = ownerUserId }

            let dto = SavedFoodDTO(from: food)
            if food.deletedAt != nil {
                try await api.delete("saved-foods/\(food.id.uuidString)")
                context.delete(food)
            } else {
                _ = try await api.post("saved-foods", body: dto) as EmptyResponse
            }
            try? context.save()
        }
    }

    private func pushSettings(ownerUserId: UUID) async throws {
        let settings = await MainActor.run { UserSettings.shared }
        let dto = await MainActor.run {
            UserSettingsDTO(
                dailyCalorieGoal: settings.dailyCalorieGoal,
                showCalorieRange: settings.showCalorieRange,
                hasCompletedOnboarding: settings.hasCompletedOnboarding
            )
        }
        _ = try await api.post("settings", body: dto) as EmptyResponse
        _ = ownerUserId
    }

    // MARK: - Merge helpers

    private func applyMerge(_ response: SyncStateResponse, ownerUserId: UUID, context: ModelContext) async throws {
        // Meals — upsert by id.
        for incoming in response.meals {
            let id = incoming.id
            let descriptor = FetchDescriptor<MealEntry>(predicate: #Predicate { $0.id == id })
            let existing = try context.fetch(descriptor).first
            if let existing {
                // Last-write-wins: only overwrite if server is newer.
                guard incoming.updatedAt > existing.updatedAt else { continue }
                // Server tombstone wins → physically delete locally (cascades
                // to food items) instead of keeping a soft-deleted shell row.
                // Without this, tombstones accumulate forever since the @Query
                // predicate only hides them.
                if incoming.deletedAt != nil {
                    context.delete(existing)
                    continue
                }
                existing.date = incoming.date
                existing.mealType = MealType(rawValue: incoming.mealType) ?? existing.mealType
                existing.totalCaloriesMin = incoming.totalMin
                existing.totalCaloriesMax = incoming.totalMax
                existing.totalCaloriesAvg = incoming.totalAvg
                existing.assumptions = incoming.assumptions ?? existing.assumptions
                existing.updatedAt = incoming.updatedAt
                existing.deletedAt = nil
                existing.photoRemoteId = incoming.photoId
                existing.ownerUserId = ownerUserId
                // Replace food items — insert the fresh ones into the context
                // explicitly so the inverse relationship is wired before save.
                for item in existing.foodItems { context.delete(item) }
                let newItems = incoming.foodItems.map { $0.toModel() }
                for item in newItems { context.insert(item) }
                existing.foodItems = newItems
            } else if incoming.deletedAt == nil {
                let newItems = incoming.foodItems.map { $0.toModel() }
                let meal = MealEntry(
                    id: incoming.id,
                    date: incoming.date,
                    mealType: MealType(rawValue: incoming.mealType) ?? .snack,
                    totalCaloriesMin: incoming.totalMin,
                    totalCaloriesMax: incoming.totalMax,
                    totalCaloriesAvg: incoming.totalAvg,
                    imageData: nil,
                    foodItems: [],
                    assumptions: incoming.assumptions ?? [],
                    ownerUserId: ownerUserId,
                    updatedAt: incoming.updatedAt,
                    deletedAt: nil,
                    photoRemoteId: incoming.photoId
                )
                context.insert(meal)
                for item in newItems { context.insert(item) }
                meal.foodItems = newItems
            }
        }

        // Saved foods — same pattern.
        for incoming in response.savedFoods {
            let id = incoming.id
            let descriptor = FetchDescriptor<SavedFood>(predicate: #Predicate { $0.id == id })
            let existing = try context.fetch(descriptor).first
            if let existing {
                guard incoming.updatedAt > existing.updatedAt else { continue }
                if incoming.deletedAt != nil {
                    context.delete(existing)
                    continue
                }
                existing.name = incoming.name
                existing.caloriesPer100g = incoming.calPer100g
                existing.proteinPer100g = incoming.protein
                existing.carbsPer100g = incoming.carbs
                existing.fatPer100g = incoming.fat
                existing.fiberPer100g = incoming.fiber
                existing.sodiumPer100g = incoming.sodium
                existing.defaultServingSizeG = incoming.defaultServingG
                existing.defaultServingLabel = incoming.defaultServingLabel
                existing.searchCount = incoming.searchCount
                existing.isFromAI = incoming.isFromAI
                existing.updatedAt = incoming.updatedAt
                existing.deletedAt = nil
                existing.ownerUserId = ownerUserId
            } else if incoming.deletedAt == nil {
                let food = SavedFood(
                    id: incoming.id,
                    name: incoming.name,
                    caloriesPer100g: incoming.calPer100g,
                    proteinPer100g: incoming.protein,
                    carbsPer100g: incoming.carbs,
                    fatPer100g: incoming.fat,
                    fiberPer100g: incoming.fiber,
                    sodiumPer100g: incoming.sodium,
                    defaultServingSizeG: incoming.defaultServingG,
                    defaultServingLabel: incoming.defaultServingLabel,
                    searchCount: incoming.searchCount,
                    isFromAI: incoming.isFromAI,
                    dateAdded: incoming.dateAdded,
                    ownerUserId: ownerUserId,
                    updatedAt: incoming.updatedAt
                )
                context.insert(food)
            }
        }

        // Settings — singleton.
        if let s = response.settings {
            await MainActor.run {
                let settings = UserSettings.shared
                settings.dailyCalorieGoal = s.dailyCalorieGoal
                settings.showCalorieRange = s.showCalorieRange
                settings.hasCompletedOnboarding = s.hasCompletedOnboarding
            }
        }

        try context.save()
    }
}

// MARK: - DTOs (wire shapes)

private struct PhotoMeta: Encodable {
    let mealId: UUID
}

struct MealDTO: Codable {
    let id: UUID
    let date: Date
    let mealType: String
    let totalMin: Int
    let totalMax: Int
    let totalAvg: Int
    let assumptions: [String]?
    let foodItems: [FoodItemDTO]
    let photoId: String?
    let updatedAt: Date
    let deletedAt: Date?

    init(from m: MealEntry) {
        self.id = m.id
        self.date = m.date
        self.mealType = m.mealType.rawValue
        self.totalMin = m.totalCaloriesMin
        self.totalMax = m.totalCaloriesMax
        self.totalAvg = m.totalCaloriesAvg
        self.assumptions = m.assumptions
        self.foodItems = m.foodItems.map { FoodItemDTO(from: $0) }
        self.photoId = m.photoRemoteId
        self.updatedAt = m.updatedAt
        self.deletedAt = m.deletedAt
    }
}

struct FoodItemDTO: Codable {
    let id: UUID
    let name: String
    let portionSize: String
    let calMin: Int
    let calMax: Int
    let calAvg: Int
    let confidence: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sugar: Double?
    let saturatedFat: Double?
    let transFat: Double?
    let cholesterol: Double?
    let sodium: Double?
    let potassium: Double?
    let updatedAt: Date
    let deletedAt: Date?

    init(from f: FoodItem) {
        self.id = f.id
        self.name = f.name
        self.portionSize = f.portionSize
        self.calMin = f.caloriesMin
        self.calMax = f.caloriesMax
        self.calAvg = f.caloriesAvg
        self.confidence = f.confidence
        self.protein = f.protein
        self.carbs = f.carbs
        self.fat = f.fat
        self.fiber = f.fiber
        self.sugar = f.sugar
        self.saturatedFat = f.saturatedFat
        self.transFat = f.transFat
        self.cholesterol = f.cholesterol
        self.sodium = f.sodium
        self.potassium = f.potassium
        self.updatedAt = f.updatedAt
        self.deletedAt = f.deletedAt
    }

    func toModel() -> FoodItem {
        FoodItem(
            id: id, name: name,
            caloriesMin: calMin, caloriesMax: calMax, caloriesAvg: calAvg,
            portionSize: portionSize, confidence: confidence,
            protein: protein, carbs: carbs, fat: fat, fiber: fiber, sugar: sugar,
            saturatedFat: saturatedFat, transFat: transFat,
            cholesterol: cholesterol, sodium: sodium, potassium: potassium,
            updatedAt: updatedAt, deletedAt: deletedAt
        )
    }
}

struct SavedFoodDTO: Codable {
    let id: UUID
    let name: String
    let calPer100g: Double
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let fiber: Double?
    let sodium: Double?
    let defaultServingG: Double
    let defaultServingLabel: String
    let searchCount: Int
    let isFromAI: Bool
    let dateAdded: Date
    let updatedAt: Date
    let deletedAt: Date?

    init(from f: SavedFood) {
        self.id = f.id
        self.name = f.name
        self.calPer100g = f.caloriesPer100g
        self.protein = f.proteinPer100g
        self.carbs = f.carbsPer100g
        self.fat = f.fatPer100g
        self.fiber = f.fiberPer100g
        self.sodium = f.sodiumPer100g
        self.defaultServingG = f.defaultServingSizeG
        self.defaultServingLabel = f.defaultServingLabel
        self.searchCount = f.searchCount
        self.isFromAI = f.isFromAI
        self.dateAdded = f.dateAdded
        self.updatedAt = f.updatedAt
        self.deletedAt = f.deletedAt
    }
}

struct UserSettingsDTO: Codable {
    let dailyCalorieGoal: Int
    let showCalorieRange: Bool
    let hasCompletedOnboarding: Bool
}

struct SyncStateResponse: Decodable {
    let meals: [MealDTO]
    let savedFoods: [SavedFoodDTO]
    let settings: UserSettingsDTO?
    let serverTime: Date?
}
