import SwiftUI
import SwiftData

/// Settings → Account block. Shows profile and sync status.
struct AccountSection: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var sync: SyncCoordinator
    @State private var showingNameEditor = false
    @State private var draftName = ""
    @State private var isSavingName = false
    @State private var nameError: String?

    var body: some View {
        Section {
            if let user = auth.currentUser {
                HStack(spacing: 12) {
                    AsyncImage(url: user.photoURL.flatMap { URL(string: $0) }) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(.gray.opacity(0.2))
                            .overlay(Text(initials(user)).font(.headline))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName(for: user)).font(.headline)
                        Text(user.email).font(.caption).foregroundStyle(.secondary)
                    }

                    Spacer()

                    if isSavingName {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Button {
                            beginEditingName(for: user)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit name")
                    }
                }
            }

            HStack {
                Image(systemName: syncIconName)
                    .foregroundStyle(syncIconColor)
                Text(syncLabel)
                    .font(.footnote)
                Spacer()
                if case .syncing = sync.state {
                    ProgressView().scaleEffect(0.8)
                }
            }
        } header: {
            Text("Account")
        }
        .alert("Edit Name", isPresented: $showingNameEditor) {
            TextField("Name", text: $draftName)
                .textContentType(.name)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)

            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveName()
            }
        } message: {
            Text("Leave blank to remove your name.")
        }
        .alert("Couldn't update name", isPresented: .constant(nameError != nil)) {
            Button("OK") { nameError = nil }
        } message: {
            Text(nameError ?? "")
        }
    }

    private func beginEditingName(for user: RemoteUser) {
        draftName = user.name ?? ""
        showingNameEditor = true
    }

    private func saveName() {
        isSavingName = true
        Task { @MainActor in
            do {
                try await auth.updateName(draftName)
            } catch {
                nameError = error.localizedDescription
            }
            isSavingName = false
        }
    }

    private func initials(_ user: RemoteUser) -> String {
        let parts = displayName(for: user).split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func displayName(for user: RemoteUser) -> String {
        let name = user.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? user.email : name
    }

    private var syncIconName: String {
        switch sync.state {
        case .idle: return "checkmark.icloud"
        case .syncing: return "icloud.and.arrow.up"
        case .failed: return "exclamationmark.icloud"
        }
    }

    private var syncIconColor: Color {
        switch sync.state {
        case .idle: return .green
        case .syncing: return .blue
        case .failed: return .orange
        }
    }

    private var syncLabel: String {
        switch sync.state {
        case .idle:
            if let date = sync.lastSyncedAt {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                return "Synced \(formatter.localizedString(for: date, relativeTo: Date()))"
            } else {
                return "All changes saved"
            }
        case .syncing: return "Syncing…"
        case .failed(let message): return "Sync failed: \(message)"
        }
    }
}

/// Settings → bottom account actions. Keeps destructive account deletion
/// visually separated from sign-out to reduce accidental taps.
struct AccountActionsSection: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var sync: SyncCoordinator
    @Environment(\.modelContext) private var modelContext

    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        Section {
            Button(role: .none) {
                showSignOutConfirm = true
            } label: {
                Label("Sign out", systemImage: "arrow.backward.circle")
            }
        }

        Section {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                if isDeleting {
                    Label("Deleting account…", systemImage: "trash")
                } else {
                    Label("Delete account", systemImage: "trash")
                }
            }
            .disabled(isDeleting)
        } footer: {
            Text("Deleting your account permanently removes your meals, saved foods, public wall posts, likes, reports, blocks, and settings from our servers.")
        }
        .confirmationDialog("Sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task {
                    await auth.signOut()
                    sync.resetForSignOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your data stays on our server. Sign back in anytime to restore it.")
        }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your account, meal history, photos, saved foods, wall posts, likes, reports, and blocks from our servers and this device. This cannot be undone.")
        }
        .alert("Couldn't delete account", isPresented: .constant(deleteError != nil)) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            do {
                try await auth.deleteAccount()
                await wipeLocalStore()
                sync.resetForSignOut()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }

    @MainActor
    private func wipeLocalStore() async {
        do {
            try modelContext.delete(model: MealEntry.self)
            try modelContext.delete(model: FoodItem.self)
            try modelContext.delete(model: SavedFood.self)
            try modelContext.delete(model: SyncOp.self)
            try modelContext.delete(model: AuthUser.self)
            try modelContext.save()
        } catch {
            #if DEBUG
            print("[AccountSection] local wipe failed: \(error)")
            #endif
        }
    }
}
