import Foundation

@MainActor
final class WallViewModel: ObservableObject {
    @Published var sortMode: WallSortMode = .recent
    @Published private(set) var posts: [WallPost] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var actionMessage: String?

    private let service: WallService

    init(service: WallService? = nil) {
        self.service = service ?? .shared
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            posts = try await service.fetchPosts(sort: sortMode)
        } catch {
            handle(error)
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            posts = try await service.fetchPosts(sort: sortMode)
        } catch {
            handle(error)
        }
    }

    func setSortMode(_ mode: WallSortMode) {
        guard mode != sortMode else { return }
        sortMode = mode
        Task { await load() }
    }

    func toggleLike(_ post: WallPost) async {
        await updatePostAction(post) {
            try await service.setLiked(!post.isLiked, postId: post.id)
        }
    }

    func report(_ post: WallPost, reason: WallReportReason, details: String?) async {
        do {
            try await service.report(postId: post.id, reason: reason, details: details)
            posts.removeAll { $0.id == post.id }
            actionMessage = "Post reported."
        } catch {
            handle(error)
        }
    }

    func block(_ post: WallPost) async {
        do {
            try await service.block(userId: post.userId)
            posts.removeAll { $0.userId == post.userId }
            actionMessage = "\(post.authorFirstName) blocked."
        } catch {
            handle(error)
        }
    }

    func delete(_ post: WallPost) async {
        do {
            try await service.delete(postId: post.id)
            posts.removeAll { $0.id == post.id }
            actionMessage = "Post deleted."
        } catch {
            handle(error)
        }
    }

    private func updatePostAction(
        _ post: WallPost,
        action: () async throws -> WallActionState
    ) async {
        do {
            let state = try await action()
            guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }
            posts[index].likeCount = state.likeCount
            posts[index].isLiked = state.isLiked
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        guard !error.isCancellation else { return }
        errorMessage = error.localizedDescription
    }
}

private extension Error {
    var isCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError {
            return urlError.code == .cancelled
        }

        if let apiError = self as? APIError {
            switch apiError {
            case .transport(let error):
                return error.isCancellation
            default:
                return false
            }
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
