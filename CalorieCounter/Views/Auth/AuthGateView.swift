import SwiftUI

/// Gates the rest of the app behind sign-in. While a persisted session is being
/// restored, keeps auth UI off-screen so returning users do not see a sign-in
/// flash before their session resolves.
struct AuthGateView<Content: View>: View {
    @EnvironmentObject private var auth: AuthService
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if auth.isRestoringSession {
                SessionRestoreView()
            } else if auth.isAuthenticated {
                content()
            } else {
                SignInView()
            }
        }
    }
}

private struct SessionRestoreView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.green)

                ProgressView()
                    .tint(.green)
            }
        }
    }
}
