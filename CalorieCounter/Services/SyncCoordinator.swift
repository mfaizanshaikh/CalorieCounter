import Foundation
import SwiftData
import SwiftUI
import Combine
import Network

/// Main-actor bridge between SwiftUI and `SyncService`. Owns the container
/// reference, listens for foreground / reachability events, and debounces
/// trigger calls. Sync engine state is exposed for the UI ("Syncing…" indicators).
@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    enum State: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastSyncedAt: Date?

    private var container: ModelContainer?
    private var cancellables = Set<AnyCancellable>()
    private var debounceTask: Task<Void, Never>?
    private let monitor = NWPathMonitor()
    private var isOnline: Bool = true

    private init() {
        // Foreground hook.
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in self?.triggerSync(pullFirst: true) }
            .store(in: &cancellables)

        // Reachability hook.
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let online = path.status == .satisfied
                let wasOffline = self?.isOnline == false
                self?.isOnline = online
                if online && wasOffline { self?.triggerSync(pullFirst: false) }
            }
        }
        monitor.start(queue: DispatchQueue(label: "sync.reachability"))
    }

    /// Wire the shared SwiftData container after the app builds it.
    func attach(container: ModelContainer) {
        self.container = container
    }

    /// Debounced sync trigger. Multiple calls in quick succession collapse
    /// into a single run (300ms quiet period).
    func triggerSync(pullFirst: Bool = false) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSync(pullFirst: pullFirst)
        }
    }

    /// First-sign-in: claim local data + bulk upload to the new account.
    func runFirstSignInMigrationIfNeeded(userId: UUID) async {
        guard let container else { return }
        do {
            try await SyncService.shared.runMigrationIfNeeded(using: container, ownerUserId: userId)
            try await SyncService.shared.pull(using: container, ownerUserId: userId)
            self.lastSyncedAt = Date()
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    /// Called when the user signs out — clears local sync bookkeeping and
    /// wipes the SwiftData store so the next account on this device starts
    /// from a clean slate.
    func resetForSignOut() {
        UserDefaults.standard.removeObject(forKey: "sync.lastPushedAt.v1")
        UserDefaults.standard.removeObject(forKey: "sync.lastPulledAt.v1")
        // The "first sign-in migration" claim-and-bulk-upload step must run
        // again for whoever signs in next, so they don't inherit the previous
        // user's gating flag.
        UserDefaults.standard.removeObject(forKey: "sync.migration_v1_done")
        // Cancel both the pending debounce and any sync already in flight.
        // The same Task covers both phases (debounce sleep → runSync), so
        // cancellation propagates through URLSession and aborts in-flight
        // requests under the about-to-be-revoked token.
        debounceTask?.cancel()
        debounceTask = nil
        // Drop cached photo bytes for the signed-out user so they don't
        // linger in memory and bleed into the next account on this device.
        PhotoLoader.shared.clear()
        wipeLocalData()
        self.lastSyncedAt = nil
        self.state = .idle
    }

    /// Deletes all user-scoped SwiftData rows. Bundled foods (no owner,
    /// not from AI, no search count) are kept — they re-seed on launch
    /// from `Resources/FoodDatabase.json` and are local-only by design.
    private func wipeLocalData() {
        guard let container else { return }
        let context = ModelContext(container)
        do {
            let meals = try context.fetch(FetchDescriptor<MealEntry>())
            for meal in meals { context.delete(meal) }

            let savedFoods = try context.fetch(FetchDescriptor<SavedFood>())
            for food in savedFoods where food.ownerUserId != nil || food.isFromAI || food.searchCount > 0 {
                context.delete(food)
            }

            // Any queued mutations belong to the user who's signing out.
            let ops = try context.fetch(FetchDescriptor<SyncOp>())
            for op in ops { context.delete(op) }

            try context.save()
        } catch {
            #if DEBUG
            print("[Sync] wipeLocalData failed: \(error)")
            #endif
        }
    }

    // MARK: - Internal

    private func runSync(pullFirst: Bool) async {
        guard let container, isOnline else { return }
        guard let userId = AuthService.shared.currentUserId else { return }

        self.state = .syncing
        do {
            if pullFirst {
                try await SyncService.shared.pull(using: container, ownerUserId: userId)
            }
            try await SyncService.shared.flush(using: container, ownerUserId: userId)
            self.lastSyncedAt = Date()
            self.state = .idle
        } catch {
            // A sign-out cancels this task; treat the resulting URLError.cancelled
            // (or any cancellation) as intentional teardown rather than a sync failure.
            if Task.isCancelled || (error as? URLError)?.code == .cancelled {
                return
            }
            #if DEBUG
            print("[Sync] failed: \(error)")
            #endif
            self.state = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Mutation observers

/// Lightweight extension SwiftData mutators can call after they save. The
/// app's ViewModels call this from their save paths — keeps wiring explicit.
extension SyncCoordinator {
    /// Mark a record dirty and trigger a debounced sync.
    func recordChanged() {
        triggerSync(pullFirst: false)
    }
}
