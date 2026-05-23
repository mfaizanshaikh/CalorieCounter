import SwiftUI

/// Pre-sign-in disclosure. Required for App Store Guideline 5.1.1 / 5.1.2 —
/// users must understand what leaves their device before they consent.
struct DataSyncDisclosureView: View {
    var onDismiss: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Your data, your account")
                        .font(.title2.bold())

                    Group {
                        sectionHeader("What stays on this device")
                        bullet("Your OpenAI API key (kept securely in iOS Keychain — never uploaded).")
                        bullet("App preferences like sound or display tweaks.")
                    }

                    Group {
                        sectionHeader("What gets uploaded to our server")
                        bullet("Your account info from Apple or Google, such as name and email.")
                        bullet("Your meals, saved foods, food photos, and nutrition estimates.")
                        bullet("Your app settings, including your daily calorie goal.")
                    }

                    Group {
                        sectionHeader("Why")
                        Text("We save meals, saved foods, photos, settings, and account info so your data can sync across devices and be restored when you sign back in.")
                            .font(.callout)
                    }

                    Group {
                        sectionHeader("How long we keep it")
                        Text("Indefinitely while your account exists. You can delete your account at any time from Settings — that wipes all your data from our servers and your phone.")
                            .font(.callout)
                    }

                    Group {
                        sectionHeader("Third parties")
                        bullet("Apple / Google — only to verify it's you when signing in.")
                        bullet("OpenAI — receives food photos you submit, to analyze nutrition. They don't store them beyond the request.")
                        bullet("Firebase / Google services may process analytics or technical data if Firebase Analytics remains enabled.")
                    }

                    Link(
                        "Read the full Privacy Policy",
                        destination: URL(string: "https://mfaizanshaikh.wordpress.com/2026/02/27/privacy-policy-ai-calorie-coach/")!
                    )
                    .font(.callout.bold())
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .navigationTitle("Data & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.primary)
            .padding(.top, 4)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 5))
                .foregroundStyle(.green)
                .padding(.top, 5)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
