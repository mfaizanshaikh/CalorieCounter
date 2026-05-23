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
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            posts = try await service.fetchPosts(sort: sortMode)
        } catch {
            errorMessage = error.localizedDescription
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

    func toggleSave(_ post: WallPost) async {
        await updatePostAction(post) {
            try await service.setSaved(!post.isSaved, postId: post.id)
        }
    }

    func report(_ post: WallPost, reason: WallReportReason, details: String?) async {
        do {
            try await service.report(postId: post.id, reason: reason, details: details)
            posts.removeAll { $0.id == post.id }
            actionMessage = "Post reported."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func block(_ post: WallPost) async {
        do {
            try await service.block(userId: post.userId)
            posts.removeAll { $0.userId == post.userId }
            actionMessage = "\(post.authorFirstName) blocked."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ post: WallPost) async {
        do {
            try await service.delete(postId: post.id)
            posts.removeAll { $0.id == post.id }
            actionMessage = "Post deleted."
        } catch {
            errorMessage = error.localizedDescription
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
            posts[index].saveCount = state.saveCount
            posts[index].isLiked = state.isLiked
            posts[index].isSaved = state.isSaved
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
