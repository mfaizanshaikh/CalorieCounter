import Foundation
import AuthenticationServices
import SwiftUI
import GoogleSignIn
import FirebaseCore

/// Owns sign-in (Google + Apple), session tokens, current user, sign-out,
/// account deletion. UI observes `isAuthenticated` and `currentUser`.
/// Runs on the main actor because it drives UI state and presents the Apple
/// authorization controller.
@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var currentUser: RemoteUser?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isSigningIn: Bool = false
    @Published var lastError: String?

    private init() {
        Task { await APIClient.shared.configure(
            baseURL: BackendConfig.baseURL,
            accessTokenProvider: { [weak self] in await self?.accessToken() },
            refreshHandler: { [weak self] in
                guard let self else { throw AuthError.notSignedIn }
                return try await self.refreshAccessToken()
            }
        ) }
    }

    // MARK: - Public state

    /// Returns the current user's UUID (used to tag local SwiftData records).
    var currentUserId: UUID? { currentUser?.id }

    var accessTokenString: String? {
        KeychainHelper.load(for: BackendConfig.KeychainKey.accessToken)
    }

    // MARK: - Session restore on launch

    /// Called from app start. If we have a refresh token, fetch the cached
    /// user via /auth/me; the APIClient will refresh the access token if needed.
    func restoreSession() async {
        guard KeychainHelper.load(for: BackendConfig.KeychainKey.refreshToken) != nil else {
            return
        }

        do {
            let user: RemoteUser = try await APIClient.shared.get("auth/me")
            self.currentUser = user
            self.isAuthenticated = true
            // Pull server changes on cold start. The willEnterForeground hook
            // doesn't fire on initial launch, so without this nudge a relaunched
            // signed-in app shows stale local state until backgrounded.
            SyncCoordinator.shared.triggerSync(pullFirst: true)
        } catch {
            // If /auth/me fails (revoked refresh token etc.), leave unauthenticated.
            #if DEBUG
            print("[AuthService] restoreSession failed: \(error)")
            #endif
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle(presenting: UIViewController) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }

        do {
            // Configure GIDSignIn once with the iOS clientID from GoogleService-Info.plist.
            if GIDSignIn.sharedInstance.configuration == nil {
                guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                      let plist = NSDictionary(contentsOfFile: path),
                      let clientID = plist["CLIENT_ID"] as? String
                else { throw AuthError.googleConfigMissing }
                GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.googleNoIdToken
            }
            try await exchangeWithBackend(
                provider: .google,
                idToken: idToken,
                fallbackEmail: result.user.profile?.email,
                fallbackName: result.user.profile?.name,
                fallbackPhoto: result.user.profile?.imageURL(withDimension: 200)?.absoluteString
            )
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    // MARK: - Sign in with Apple

    /// Called by `SignInWithAppleButton.onCompletion` with a credential.
    func completeAppleSignIn(result: Result<ASAuthorization, Error>) async {
        guard !isSigningIn else { return }
        isSigningIn = true
        lastError = nil
        defer { isSigningIn = false }

        switch result {
        case .failure(let error):
            self.lastError = error.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                self.lastError = AuthError.appleNoIdToken.localizedDescription
                return
            }
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespaces)
            do {
                try await exchangeWithBackend(
                    provider: .apple,
                    idToken: idToken,
                    fallbackEmail: credential.email,
                    fallbackName: name.isEmpty ? nil : name,
                    fallbackPhoto: nil
                )
            } catch {
                self.lastError = error.localizedDescription
            }
        }
    }

    // MARK: - Sign out

    func signOut() async {
        // Best effort: tell server, then nuke locally regardless.
        do {
            _ = try await APIClient.shared.post("auth/logout", body: EmptyBody()) as EmptyResponse
        } catch { /* ignore */ }
        clearLocalAuthState()
        GIDSignIn.sharedInstance.signOut()
        // Wipe local SwiftData + sync bookkeeping so a different account on the
        // same device doesn't inherit the previous user's meals/saved foods.
        SyncCoordinator.shared.resetForSignOut()
    }

    // MARK: - Account deletion (App Store Guideline 5.1.1(v))

    /// Deletes the user's account on the server and wipes all local data.
    /// Caller is responsible for tearing down the local SwiftData store.
    func deleteAccount() async throws {
        try await APIClient.shared.delete("account")
        clearLocalAuthState()
        GIDSignIn.sharedInstance.signOut()
        SyncCoordinator.shared.resetForSignOut()
    }

    // MARK: - Profile updates

    func updateName(_ name: String) async throws {
        struct Req: Encodable { let name: String }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let user: RemoteUser = try await APIClient.shared.patch(
            "auth/me",
            body: Req(name: trimmedName)
        )
        self.currentUser = user
    }

    // MARK: - Token plumbing

    fileprivate func accessToken() async -> String? {
        KeychainHelper.load(for: BackendConfig.KeychainKey.accessToken)
    }

    /// Hits /auth/refresh, stores the new tokens, returns the new access token.
    /// Throws if no refresh token, or if refresh fails.
    fileprivate func refreshAccessToken() async throws -> String {
        guard let refresh = KeychainHelper.load(for: BackendConfig.KeychainKey.refreshToken) else {
            throw AuthError.notSignedIn
        }
        struct Req: Encodable { let refreshToken: String }
        struct Res: Decodable { let accessToken: String; let refreshToken: String }
        let res: Res = try await APIClient.shared.post("auth/refresh", body: Req(refreshToken: refresh))
        KeychainHelper.save(res.accessToken, for: BackendConfig.KeychainKey.accessToken)
        KeychainHelper.save(res.refreshToken, for: BackendConfig.KeychainKey.refreshToken)
        return res.accessToken
    }

    // MARK: - Backend exchange

    private func exchangeWithBackend(
        provider: AuthProvider,
        idToken: String,
        fallbackEmail: String?,
        fallbackName: String?,
        fallbackPhoto: String?
    ) async throws {
        struct Req: Encodable {
            let provider: String
            let idToken: String
            let email: String?
            let name: String?
            let photoURL: String?
        }
        struct Res: Decodable {
            let accessToken: String
            let refreshToken: String
            let user: RemoteUser
        }
        let res: Res = try await APIClient.shared.post(
            "auth/login",
            body: Req(
                provider: provider.rawValue,
                idToken: idToken,
                email: fallbackEmail,
                name: fallbackName,
                photoURL: fallbackPhoto
            )
        )
        KeychainHelper.save(res.accessToken, for: BackendConfig.KeychainKey.accessToken)
        KeychainHelper.save(res.refreshToken, for: BackendConfig.KeychainKey.refreshToken)
        KeychainHelper.save(res.user.id.uuidString, for: BackendConfig.KeychainKey.userId)
        self.currentUser = res.user
        self.isAuthenticated = true

        // Kick off first-sign-in migration on a background task.
        await SyncCoordinator.shared.runFirstSignInMigrationIfNeeded(userId: res.user.id)
    }

    private func clearLocalAuthState() {
        KeychainHelper.delete(for: BackendConfig.KeychainKey.accessToken)
        KeychainHelper.delete(for: BackendConfig.KeychainKey.refreshToken)
        KeychainHelper.delete(for: BackendConfig.KeychainKey.userId)
        self.currentUser = nil
        self.isAuthenticated = false
    }
}

// MARK: - Models

struct RemoteUser: Codable, Identifiable, Equatable {
    let id: UUID
    let email: String
    let name: String?
    let photoURL: String?
    let provider: AuthProvider

    static let placeholder = RemoteUser(id: UUID(), email: "", name: nil, photoURL: nil, provider: .google)
}

enum AuthError: LocalizedError {
    case googleConfigMissing
    case googleNoIdToken
    case appleNoIdToken
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .googleConfigMissing: return "Google Sign-In is not configured correctly."
        case .googleNoIdToken: return "Google did not return a valid token."
        case .appleNoIdToken: return "Apple did not return a valid token."
        case .notSignedIn: return "You are not signed in."
        }
    }
}
