import Foundation

/// Discover 画面の ViewModel。
/// - 非検索時: Post + Project を新着順で混合した masonry feed を表示
/// - 検索時: SearchRepository で user/post を横断検索
@MainActor @Observable
final class DiscoverViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let searchRepository: any SearchRepositoryProtocol
    @ObservationIgnored private let postRepository: any PostRepositoryProtocol
    @ObservationIgnored private let appRepository: any AppRepositoryProtocol

    // MARK: - Search state

    var searchQuery = ""
    var isSearching = false
    var searchResults: SearchResults?
    var errorMessage: String?

    var isShowingResults: Bool {
        !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Feed state

    var feedItems: [FeedItem] = []
    var isLoadingFeed = false
    var isLoadingMore = false
    var hasMoreFeed = true

    /// Page end cursor. Post と Project で別管理 (各 source から最古の createdAt)。
    /// 次ページ取得時は両 source をそれぞれ個別 cursor で fetch → merge。
    private var postCursor: Date?
    private var appCursor: Date?
    private var postsExhausted = false
    private var appsExhausted = false

    // MARK: - Init

    init(
        searchRepository: any SearchRepositoryProtocol,
        postRepository: any PostRepositoryProtocol,
        appRepository: any AppRepositoryProtocol
    ) {
        self.searchRepository = searchRepository
        self.postRepository = postRepository
        self.appRepository = appRepository
    }

    // MARK: - Feed actions

    func loadFeed() async {
        guard !isLoadingFeed else { return }
        isLoadingFeed = true
        defer { isLoadingFeed = false }

        postCursor = nil
        appCursor = nil
        postsExhausted = false
        appsExhausted = false
        hasMoreFeed = true

        let items = await fetchMergedPage(postCursor: nil, appCursor: nil)
        feedItems = items
        updateCursorsAndExhaustion(from: items)
    }

    func refreshFeed() async {
        await loadFeed()
    }

    func loadMoreFeed() async {
        guard !isLoadingMore, hasMoreFeed else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        let items = await fetchMergedPage(postCursor: postCursor, appCursor: appCursor)
        guard !items.isEmpty else {
            hasMoreFeed = false
            return
        }
        feedItems.append(contentsOf: items)
        updateCursorsAndExhaustion(from: items)
    }

    // MARK: - Search

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            searchResults = nil
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            searchResults = try await searchRepository.search(query: query, limit: AppConfig.feedPageSize)
        } catch {
            errorMessage = String(localized: "discover.error.search")
        }
    }

    // MARK: - Private

    /// Post と Project を並列 fetch して createdAt DESC で merge。
    /// 各 source の page size は `feedPageSize`、合計で最大 2 倍。
    private func fetchMergedPage(postCursor: Date?, appCursor: Date?) async -> [FeedItem] {
        async let postsTask: [Post] = fetchPosts(cursor: postCursor)
        async let projectsTask: [Project] = fetchProjects(cursor: appCursor)

        let posts = await postsTask
        let projects = await projectsTask

        let items = posts.map(FeedItem.post) + projects.map(FeedItem.project)
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchPosts(cursor: Date?) async -> [Post] {
        if postsExhausted { return [] }
        do {
            // Discover は「読む意味のある投稿」限定 (media / 200 文字 / リプライ 1 件以上)、server 側 RPC で絞り込み。
            let dtos = try await postRepository.fetchDiscoverFeed(cursor: cursor, limit: AppConfig.feedPageSize)
            if dtos.count < AppConfig.feedPageSize { postsExhausted = true }
            return dtos.map(Post.init(from:))
        } catch {
            return []
        }
    }

    private func fetchProjects(cursor: Date?) async -> [Project] {
        if appsExhausted { return [] }
        do {
            // status 問わず全 apps を last_bumped_at DESC で取得 (user 方針: 宣伝目的で draft/archived も表示)。
            let dtos = try await appRepository.fetchAllApps(cursor: cursor, limit: AppConfig.feedPageSize)
            if dtos.count < AppConfig.feedPageSize { appsExhausted = true }
            return dtos.map(Project.init(from:))
        } catch {
            return []
        }
    }

    private func updateCursorsAndExhaustion(from items: [FeedItem]) {
        // Post は createdAt、Project は lastBumpedAt が FeedItem.createdAt から返る。
        // それぞれ最古の日時を cursor として次 page に渡す。
        let postDates = items.compactMap { item -> Date? in
            if case .post = item { return item.createdAt } else { return nil }
        }
        let projectDates = items.compactMap { item -> Date? in
            if case .project = item { return item.createdAt } else { return nil }
        }
        if let oldest = postDates.min() { postCursor = oldest }
        if let oldest = projectDates.min() { appCursor = oldest }

        if postsExhausted && appsExhausted {
            hasMoreFeed = false
        }
    }
}
