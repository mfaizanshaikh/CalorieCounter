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

    /// Called when the user signs out — clears local sync bookkeeping so the
    /// next sign-in does a fresh pull.
    func resetForSignOut() {
        UserDefaults.standard.removeObject(forKey: "sync.lastPushedAt.v1")
        UserDefaults.standard.removeObject(forKey: "sync.lastPulledAt.v1")
        self.lastSyncedAt = nil
        self.state = .idle
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
