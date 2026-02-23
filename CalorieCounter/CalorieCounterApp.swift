import SwiftUI
import SwiftData

@main
struct CalorieCounterApp: App {
    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            MealEntry.self,
            FoodItem.self,
        ])

        // Try persistent (on-disk) store first.
        // If the store is missing or corrupted fall back to an in-memory store
        // so the app remains usable rather than crashing on launch.
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [persistentConfig]) {
            sharedModelContainer = container
            return
        }

        // Persistent store failed – use in-memory so the user can still run the app.
        // Data will not survive a relaunch in this state, but the app won't crash.
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        guard let fallback = try? ModelContainer(for: schema, configurations: [fallbackConfig]) else {
            // In-memory SwiftData stores should never fail; if we reach here something is
            // deeply wrong with the SDK itself.
            preconditionFailure("Could not create any ModelContainer")
        }
        sharedModelContainer = fallback
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
