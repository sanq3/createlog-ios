import Foundation

/// ホームフィードのViewModel
@MainActor @Observable
final class FeedViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let postRepository: any PostRepositoryProtocol
    @ObservationIgnored private let likeRepository: any LikeRepositoryProtocol

    // MARK: - State

    enum FeedSegment: Int, CaseIterable {
        case timeline = 0
        case following

        var label: String {
            switch self {
            case .timeline: "タイムライン"
            case .following: "フォロー中"
            }
        }
    }

    var segment: FeedSegment = .timeline
    /// UIで使用するドメイン型のポスト一覧
    var posts: [Post] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?

    @ObservationIgnored private var oldestCursor: Date?

    // MARK: - Init

    init(postRepository: any PostRepositoryProtocol, likeRepository: any LikeRepositoryProtocol) {
        self.postRepository = postRepository
        self.likeRepository = likeRepository
    }

    // MARK: - Feed Loading

    func loadFeed() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let dtos = try await fetchPosts(cursor: nil)
            posts = dtos.map { Post(from: $0) }
            oldestCursor = dtos.last?.createdAt
            hasMore = dtos.count >= AppConfig.feedPageSize
        } catch {
            errorMessage = String(localized: "feed.error.load")
        }
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore, let cursor = oldestCursor else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let dtos = try await fetchPosts(cursor: cursor)
            posts.append(contentsOf: dtos.map { Post(from: $0) })
            oldestCursor = dtos.last?.createdAt ?? oldestCursor
            hasMore = dtos.count >= AppConfig.feedPageSize
        } catch {
            // サイレント
        }
    }

    func refresh() async {
        oldestCursor = nil
        await loadFeed()
    }

    func onSegmentChange() async {
        posts = []
        oldestCursor = nil
        await loadFeed()
    }

    // MARK: - Actions

    func toggleLike(postId: UUID) async {
        guard let index = posts.firstIndex(where: { $0.id == postId }) else { return }

        // オプティミスティックUI: いいね状態を反転して即座に反映
        let wasLiked = posts[index].isLiked
        posts[index].isLiked = !wasLiked
        posts[index].likes += wasLiked ? -1 : 1

        do {
            if wasLiked {
                try await likeRepository.unlike(postId: postId)
            } else {
                try await likeRepository.like(postId: postId)
            }
        } catch {
            // ロールバック
            if let i = posts.firstIndex(where: { $0.id == postId }) {
                posts[i].isLiked = wasLiked
                posts[i].likes += wasLiked ? 1 : -1
            }
        }
    }

    // MARK: - Private

    private func fetchPosts(cursor: Date?) async throws -> [PostDTO] {
        switch segment {
        case .timeline:
            return try await postRepository.fetchFeed(cursor: cursor, limit: AppConfig.feedPageSize)
        case .following:
            return try await postRepository.fetchFollowingFeed(cursor: cursor, limit: AppConfig.feedPageSize)
        }
    }
}
