import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var showDisclosure = false
    @State private var disclosureSeen = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.green.opacity(0.12), Color.green.opacity(0.04), Color(.systemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .foregroundStyle(.green)
                    Text("AI Calorie Coach")
                        .font(.system(size: 28, weight: .bold))
                    Text("Sign in to back up your meal history so you never lose it — even if you switch phones.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Apple FIRST per Apple's Sign in with Apple guidelines.
                    SignInWithAppleButton(
                        .signIn,
                        onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        },
                        onCompletion: { result in
                            Task { await auth.completeAppleSignIn(result: result) }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .cornerRadius(12)

                    Button(action: signInWithGoogle) {
                        HStack(spacing: 10) {
                            Image(systemName: "g.circle.fill")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(.white)
                            Text("Sign in with Google")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(auth.isSigningIn)
                }
                .frame(maxWidth: 375)
                .padding(.horizontal, 24)

                Button {
                    showDisclosure = true
                } label: {
                    Text("What data is stored?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .underline()
                }
                .padding(.top, 4)

                if let error = auth.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Text("By signing in you agree to our [Privacy Policy](https://mfaizanshaikh.wordpress.com/2026/02/27/privacy-policy-ai-calorie-coach/).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 12)
            }
        }
        .sheet(isPresented: $showDisclosure) {
            DataSyncDisclosureView { disclosureSeen = true }
        }
        .onAppear {
            // Show disclosure once per fresh install before the user signs in.
            if !UserDefaults.standard.bool(forKey: "auth.disclosureSeen") {
                showDisclosure = true
                UserDefaults.standard.set(true, forKey: "auth.disclosureSeen")
            }
        }
    }

    private func signInWithGoogle() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return }
        Task { await auth.signInWithGoogle(presenting: root) }
    }
}
