import Foundation

enum WallSortMode: String, CaseIterable, Identifiable {
    case recent
    case trending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: return "Recent"
        case .trending: return "Trending"
        }
    }
}

enum WallReportReason: String, CaseIterable, Identifiable, Codable {
    case offensiveContent = "offensive_content"
    case nonFoodImage = "non_food_image"
    case privacyConcern = "privacy_concern"
    case spam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .offensiveContent: return "Offensive content"
        case .nonFoodImage: return "Non-food image"
        case .privacyConcern: return "Privacy concern"
        case .spam: return "Spam"
        case .other: return "Other"
        }
    }
}

struct WallPost: Identifiable, Decodable, Equatable {
    let id: UUID
    let userId: UUID
    let authorFirstName: String
    let mealType: String
    let foodNames: [String]
    let totalCaloriesMin: Int
    let totalCaloriesMax: Int
    let totalCaloriesAvg: Int
    let protein: Double?
    let carbs: Double?
    let fat: Double?
    let status: String
    let postedAt: Date
    var likeCount: Int
    var isLiked: Bool
    let isMine: Bool
    let photoPath: String

    var foodSummary: String {
        foodNames.joined(separator: ", ")
    }
}

struct WallPostsResponse: Decodable {
    let posts: [WallPost]
}

struct WallPostResponse: Decodable {
    let post: WallPost
}

struct WallActionState: Decodable {
    let likeCount: Int
    let isLiked: Bool
}

struct WallActionStateResponse: Decodable {
    let state: WallActionState
}

struct WallStatusResponse: Decodable {
    let status: String
}
