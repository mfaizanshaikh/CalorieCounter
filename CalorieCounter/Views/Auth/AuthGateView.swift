import SwiftUI

/// Gates the rest of the app behind sign-in. Once `AuthService.isAuthenticated`
/// flips true, renders `content`. Shows the sign-in/disclosure flow otherwise.
struct AuthGateView<Content: View>: View {
    @EnvironmentObject private var auth: AuthService
    @ViewBuilder var content: () -> Content

    var body: some View {
        Group {
            if auth.isAuthenticated {
                content()
            } else {
                SignInView()
            }
        }
    }
}
