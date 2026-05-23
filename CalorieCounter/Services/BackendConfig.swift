import Foundation

/// Central configuration for the PHP backend. Edit `baseURLString` before
/// shipping. Reads from Info.plist key `BackendBaseURL` first (so the value
/// can be overridden per build configuration via xcconfig / build settings),
/// falling back to the compile-time default below.
enum BackendConfig {
    /// Compile-time fallback used if the Info.plist build setting is missing.
    private static let defaultBaseURL = "https://mfaizanshaikh.com/ai-calorie-coach/api"

    static var baseURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "BackendBaseURL") as? String).flatMap {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty || value.hasPrefix("$(") ? nil : value
        } ?? defaultBaseURL
        guard let url = URL(string: raw) else {
            preconditionFailure("Invalid BackendBaseURL: \(raw)")
        }
        return url
    }

    enum KeychainKey {
        static let accessToken = "app_session_jwt"
        static let refreshToken = "app_refresh_token"
        static let userId = "app_user_id"
    }
}
