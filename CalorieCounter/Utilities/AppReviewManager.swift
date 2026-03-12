import Foundation
import StoreKit

enum AppReviewManager {
    private static let foodLogCountKey = "app_review_food_log_count"
    private static let hasRequestedReviewKey = "app_review_has_requested"
    private static let threshold = Int.random(in: 3...5)

    /// Call after every successful food log save.
    /// Returns `true` when it's time to request a review.
    static func recordFoodLogAndCheckReview() -> Bool {
        let defaults = UserDefaults.standard
        let count = defaults.integer(forKey: foodLogCountKey) + 1
        defaults.set(count, forKey: foodLogCountKey)

        guard !defaults.bool(forKey: hasRequestedReviewKey) else { return false }

        if count >= threshold {
            defaults.set(true, forKey: hasRequestedReviewKey)
            return true
        }
        return false
    }
}
