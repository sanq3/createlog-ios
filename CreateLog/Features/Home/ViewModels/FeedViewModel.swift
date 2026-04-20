import Foundation

/// ホームフィードのViewModel
@MainActor @Observable
final class FeedViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let postRepository: any PostRepositoryProtocol
    @ObservationIgnored private let likeRepository: any LikeRepositoryProtocol
    /// Domain event bus: 他 VM の state 変更 (投稿/削除/いいね/コメント/ブロック/プロフィール更新等)
    /// を受けて Feed 側の posts[] を in-place patch する。nil なら subscribe しない (preview/test)。
    @ObservationIgnored private let eventBus: DomainEventBus?

    /// subscribe Task の二重起動防止と cancel 用。MainTabView の `.task` が
    /// 再実行されても 1 本に保つ。deinit で cancel。
    @ObservationIgnored private var subscribeTask: Task<Void, Never>?

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

    init(
        postRepository: any PostRepositoryProtocol,
        likeRepository: any LikeRepositoryProtocol,
        eventBus: DomainEventBus? = nil
    ) {
        self.postRepository = postRepository
        self.likeRepository = likeRepository
        self.eventBus = eventBus
    }

    deinit {
        // Task.cancel() は nonisolated なので deinit (nonisolated) から呼べる。
        subscribeTask?.cancel()
    }

    /// MainTabView の `.task` から 1 回だけ呼ぶ。idempotent: 既に起動済なら no-op。
    /// 全 DomainEvent を 1 本の AsyncStream で購読し、posts[] を in-place patch する。
    func startSubscribing() {
        guard subscribeTask == nil, let bus = eventBus else { return }
        subscribeTask = Task { [weak self] in
            for await event in bus.events() {
                guard let self else { return }
                self.handle(event)
            }
        }
    }

    /// DomainEvent を posts[] に反映。idempotent 設計:
    /// - 自分の VM が publish した event が巡って来ても副作用なし (同一 state なら no-op)
    /// - 他 VM (PostDetailView / ProfileEditView 等) が publish した event で画面を同期
    private func handle(_ event: DomainEvent) {
        switch event {
        case .postCreated(let post):
            // 重複挿入防止: 自身の VM が publish した場合や、複数画面が同 event を受けた場合。
            guard !posts.contains(where: { $0.id == post.id }) else { return }
            posts.insert(post, at: 0)

        case .postDeleted(let postId):
            posts.removeAll(where: { $0.id == postId })

        case .postEdited(let post):
            if let i = posts.firstIndex(where: { $0.id == post.id }) {
                posts[i] = post
            }

        case .likeToggled(let postId, let liked, let count):
            if let i = posts.firstIndex(where: { $0.id == postId }) {
                posts[i].isLiked = liked
                posts[i].likes = count
            }

        case .commentAdded(let postId, _):
            if let i = posts.firstIndex(where: { $0.id == postId }) {
                posts[i].comments += 1
            }

        case .commentDeleted(let postId, _):
            if let i = posts.firstIndex(where: { $0.id == postId }) {
                posts[i].comments = max(0, posts[i].comments - 1)
            }

        case .blockToggled(let userId, let blocked):
            // block 後は該当ユーザーの投稿を Feed から除去。unblock 時の復元は次回 refresh 待ち。
            if blocked {
                posts.removeAll(where: { $0.userId == userId })
            }

        case .profileUpdated(let userId, let name, let handle, let avatarUrl, _):
            // 現行 DB は JOIN 方式 (posts には author_* denormalize 無し) のため、
            // 次回 fetch では profiles join で最新値が取れるが、開いている画面の即時反映のため
            // client 側で in-place patch する。
            // avatarUrl: nil = 「変更なし」と解釈 (X 等は avatar 削除機能無し) → old 保持。
            for i in posts.indices where posts[i].userId == userId {
                let old = posts[i]
                posts[i] = Post(
                    id: old.id,
                    userId: old.userId,
                    name: name,
                    handle: handle,
                    status: old.status,
                    createdAt: old.createdAt,
                    workMinutes: old.workMinutes,
                    content: old.content,
                    likes: old.likes,
                    reposts: old.reposts,
                    comments: old.comments,
                    media: old.media,
                    authorAvatarUrl: avatarUrl ?? old.authorAvatarUrl
                )
                posts[i].isLiked = old.isLiked
                posts[i].isBookmarked = old.isBookmarked
            }

        case .sessionCleared:
            posts = []
            oldestCursor = nil
            hasMore = true

        case .followToggled, .notificationRead, .allNotificationsRead:
            break
        }
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
            // 成功確定 → 他 VM (PostDetailView 等) に broadcast。
            // 自分も subscribe 経路で受けるが idempotent (同値 set) なので副作用なし。
            if let i = posts.firstIndex(where: { $0.id == postId }) {
                eventBus?.publish(.likeToggled(
                    postId: postId,
                    liked: posts[i].isLiked,
                    count: posts[i].likes
                ))
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
