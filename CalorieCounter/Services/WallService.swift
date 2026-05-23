import Foundation
import SwiftData
import UIKit

@MainActor
final class WallService {
    static let shared = WallService()

    private let api: APIClient

    private init(api: APIClient = .shared) {
        self.api = api
    }

    func fetchPosts(sort: WallSortMode) async throws -> [WallPost] {
        let response: WallPostsResponse = try await api.get(
            "wall/posts",
            query: ["sort": sort.rawValue]
        )
        return response.posts
    }

    func publish(meal: MealEntry, in context: ModelContext) async throws -> WallPost {
        guard AuthService.shared.currentUserId != nil else {
            throw WallServiceError.notSignedIn
        }

        if meal.photoRemoteId == nil {
            guard let imageData = meal.imageData else {
                throw WallServiceError.photoRequired
            }
            struct PhotoRes: Decodable { let id: String }
            let response: PhotoRes = try await api.upload(
                "photos",
                jsonPart: WallPhotoMeta(mealId: meal.id),
                files: [(name: "photo", filename: "\(meal.id).jpg", mimeType: "image/jpeg", data: imageData)]
            )
            meal.photoRemoteId = response.id
            try? context.save()
        }

        _ = try await api.post("meals", body: MealDTO(from: meal)) as EmptyResponse

        let response: WallPostResponse = try await api.post(
            "wall/posts",
            body: PublishWallPostRequest(mealId: meal.id)
        )
        return response.post
    }

    func setLiked(_ liked: Bool, postId: UUID) async throws -> WallActionState {
        if liked {
            let response: WallActionStateResponse = try await api.post(
                "wall/posts/\(postId.uuidString)/like",
                body: EmptyBody()
            )
            return response.state
        }
        let response: WallActionStateResponse = try await api.deleteReturning(
            "wall/posts/\(postId.uuidString)/like"
        )
        return response.state
    }

    func setSaved(_ saved: Bool, postId: UUID) async throws -> WallActionState {
        if saved {
            let response: WallActionStateResponse = try await api.post(
                "wall/posts/\(postId.uuidString)/save",
                body: EmptyBody()
            )
            return response.state
        }
        let response: WallActionStateResponse = try await api.deleteReturning(
            "wall/posts/\(postId.uuidString)/save"
        )
        return response.state
    }

    func report(postId: UUID, reason: WallReportReason, details: String?) async throws {
        _ = try await api.post(
            "wall/posts/\(postId.uuidString)/report",
            body: ReportWallPostRequest(reason: reason.rawValue, details: details)
        ) as WallStatusResponse
    }

    func block(userId: UUID) async throws {
        _ = try await api.post(
            "wall/users/\(userId.uuidString)/block",
            body: EmptyBody()
        ) as WallStatusResponse
    }

    func delete(postId: UUID) async throws {
        try await api.delete("wall/posts/\(postId.uuidString)")
    }
}

@MainActor
final class WallPhotoLoader: ObservableObject {
    static let shared = WallPhotoLoader()

    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 80
    }

    func image(for post: WallPost) async -> UIImage? {
        let key = post.photoPath as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        if let existing = inflight[post.photoPath] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            do {
                let data = try await APIClient.shared.getData(post.photoPath)
                guard let image = UIImage(data: data) else { return nil }
                self?.cache.setObject(image, forKey: key)
                return image
            } catch {
                #if DEBUG
                print("[WallPhotoLoader] failed to fetch \(post.photoPath): \(error)")
                #endif
                return nil
            }
        }
        inflight[post.photoPath] = task
        let image = await task.value
        inflight[post.photoPath] = nil
        return image
    }
}

enum WallServiceError: LocalizedError {
    case notSignedIn
    case photoRequired

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to post to the wall."
        case .photoRequired: return "Only analyzed meals with photos can be posted to the wall."
        }
    }
}

private struct WallPhotoMeta: Encodable {
    let mealId: UUID
}

private struct PublishWallPostRequest: Encodable {
    let mealId: UUID
}

private struct ReportWallPostRequest: Encodable {
    let reason: String
    let details: String?
}
