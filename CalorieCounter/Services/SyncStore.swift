import Foundation
import SwiftData

/// Thin wrapper around SwiftData mutations that keeps `updatedAt`,
/// `ownerUserId`, and the sync queue in lockstep. Call sites that used to
/// do `context.insert(meal); context.save()` should now go through here.
enum SyncStore {

    // MARK: - MealEntry

    @MainActor
    static func save(meal: MealEntry, in context: ModelContext) {
        meal.updatedAt = Date()
        if meal.ownerUserId == nil { meal.ownerUserId = AuthService.shared.currentUserId }
        if meal.modelContext == nil { context.insert(meal) }
        try? context.save()
        SyncCoordinator.shared.recordChanged()
    }

    @MainActor
    static func delete(meal: MealEntry, in context: ModelContext) {
        // Queue a delete SyncOp BEFORE the physical delete so we don't lose the id.
        if let userId = AuthService.shared.currentUserId, meal.ownerUserId == userId {
            let op = SyncOp(
                entityType: .meal,
                entityId: meal.id,
                opType: .delete,
                payload: Data()
            )
            context.insert(op)
        }
        // If the meal had a server-side photo, the server cascade handles file removal.
        context.delete(meal)
        try? context.save()
        SyncCoordinator.shared.recordChanged()
    }

    /// Bulk-delete all meals (used by Settings → "Delete all data").
    @MainActor
    static func deleteAllMeals(in context: ModelContext) {
        let meals = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        for meal in meals { delete(meal: meal, in: context) }
    }

    // MARK: - SavedFood

    @MainActor
    static func save(savedFood: SavedFood, in context: ModelContext) {
        savedFood.updatedAt = Date()
        if savedFood.ownerUserId == nil { savedFood.ownerUserId = AuthService.shared.currentUserId }
        if savedFood.modelContext == nil { context.insert(savedFood) }
        try? context.save()
        SyncCoordinator.shared.recordChanged()
    }

    @MainActor
    static func delete(savedFood: SavedFood, in context: ModelContext) {
        if let userId = AuthService.shared.currentUserId, savedFood.ownerUserId == userId {
            let op = SyncOp(
                entityType: .savedFood,
                entityId: savedFood.id,
                opType: .delete,
                payload: Data()
            )
            context.insert(op)
        }
        context.delete(savedFood)
        try? context.save()
        SyncCoordinator.shared.recordChanged()
    }

    /// Mark a SavedFood "used" — bump searchCount and updatedAt without
    /// triggering an immediate sync (sync batched on foreground).
    @MainActor
    static func recordSearch(of food: SavedFood, in context: ModelContext) {
        food.searchCount += 1
        food.updatedAt = Date()
        try? context.save()
        SyncCoordinator.shared.recordChanged()
    }

    // MARK: - Settings

    static func settingsChanged() {
        Task { @MainActor in
            SyncCoordinator.shared.recordChanged()
        }
    }
}
