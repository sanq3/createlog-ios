import Foundation
import SwiftData

/// プロフィール画面のViewModel
@MainActor @Observable
final class ProfileViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let postRepository: any PostRepositoryProtocol
    @ObservationIgnored private let appRepository: any AppRepositoryProtocol
    @ObservationIgnored private let followRepository: any FollowRepositoryProtocol
    @ObservationIgnored private let statsRepository: any StatsRepositoryProtocol
    @ObservationIgnored private let likeRepository: any LikeRepositoryProtocol
    @ObservationIgnored private let bookmarkRepository: any BookmarkRepositoryProtocol

    // MARK: - State

    var profile: ProfileDTO?
    var posts: [PostDTO] = []
    var apps: [AppDTO] = []
    var followerCount = 0
    var followingCount = 0
    var isFollowing = false
    var totalMinutes = 0
    /// 曜日 (月〜日) ラベル + 時間 (時間単位) ペア。ProfileView の週間チャート用。
    var weeklyHours: [(day: String, hours: Double)] = []
    /// Cold cache 初回のみ true。View 側の skeleton placeholder 判定用。
    /// SWR で cache hit 時は profile != nil のため常に false。
    var isLoading = false
    /// background revalidation 中フラグ。cache 表示中に裏で remote fetch 中であることを UI に
    /// 伝える (上部に控えめなインジケータ等)。View は任意で使う。
    var isRevalidating = false
    var errorMessage: String?

    /// 自分がいいねした投稿一覧 (「いいね」タブ)。isMyProfile == true のときだけ埋める。
    var likedPosts: [PostDTO] = []
    /// 自分がブックマークした投稿一覧 (「ブックマーク」タブ)。isMyProfile == true のときだけ埋める。
    var bookmarkedPosts: [PostDTO] = []
    var isLoadingLiked = false
    var isLoadingBookmarked = false
    /// 初回遷移後の load が済んだかどうか (再 fetch 抑制用)。
    private var hasLoadedLikedOnce = false
    private var hasLoadedBookmarkedOnce = false

    /// 自分のプロフィールかどうか
    let isMyProfile: Bool
    private let targetUserId: UUID?

    // MARK: - Init

    init(
        profileRepository: any ProfileRepositoryProtocol,
        postRepository: any PostRepositoryProtocol,
        appRepository: any AppRepositoryProtocol,
        followRepository: any FollowRepositoryProtocol,
        statsRepository: any StatsRepositoryProtocol,
        likeRepository: any LikeRepositoryProtocol,
        bookmarkRepository: any BookmarkRepositoryProtocol,
        userId: UUID? = nil
    ) {
        self.profileRepository = profileRepository
        self.postRepository = postRepository
        self.appRepository = appRepository
        self.followRepository = followRepository
        self.statsRepository = statsRepository
        self.likeRepository = likeRepository
        self.bookmarkRepository = bookmarkRepository
        self.targetUserId = userId
        self.isMyProfile = userId == nil

        // 2026-04-16: SWR + Cache-first rendering (Bluesky placeholderData pattern)。
        // 同期的に SDProfileCache から profile を取得して初期値にする。cold cache なら nil。
        // これにより View 初回描画時に空 User (handle="", name="") が一瞬表示される flicker を根絶する。
        if let userId {
            self.profile = profileRepository.cachedProfile(userId: userId)
        } else {
            self.profile = profileRepository.cachedMyProfile()
        }
    }

    // MARK: - Data Loading

    func loadProfile() async {
        // cache hit 時は isRevalidating (背景 refresh)、cold cache 時は isLoading (初回待機)
        let hadCache = profile != nil
        if hadCache {
            isRevalidating = true
        } else {
            isLoading = true
        }
        defer {
            isLoading = false
            isRevalidating = false
        }

        do {
            let userId: UUID
            if let targetId = targetUserId {
                profile = try await profileRepository.fetchProfile(userId: targetId)
                apps = try await appRepository.fetchApps(userId: targetId)
                isFollowing = try await followRepository.isFollowing(userId: targetId)
                userId = targetId
            } else {
                profile = try await profileRepository.fetchMyProfile()
                apps = try await appRepository.fetchMyApps()
                totalMinutes = try await statsRepository.fetchCumulativeMinutes()
                guard let myId = profile?.id else {
                    errorMessage = "プロフィールの読み込みに失敗しました"
                    return
                }
                userId = myId
            }

            // Follower counts + 投稿 + 週間チャートを並列で取得
            async let counts = followRepository.fetchCounts(userId: userId)
            async let userPosts = postRepository.fetchUserPosts(userId: userId, cursor: nil, limit: AppConfig.feedPageSize)
            async let weekly = statsRepository.fetchWeeklyStats(containing: Date())

            let (c, p, w) = try await (counts, userPosts, weekly)
            followerCount = c.followers
            followingCount = c.following
            posts = p
            weeklyHours = Self.buildWeeklyHours(from: w)
        } catch {
            errorMessage = "プロフィールの読み込みに失敗しました"
        }
    }

    /// ローカル SDProject のうち Supabase `apps` に未同期 (`remoteAppId==nil`) のものを一括 sync。
    /// onboarding 時に同期失敗したケースや以前のビルドで sync 前終了したケースを救済し、
    /// Discover フィードに表示されるようにする。冪等 — 既同期分はスキップ、失敗時は local に残し次回 retry。
    func syncUnsyncedProjectsIfNeeded(modelContext: ModelContext) async {
        guard isMyProfile else { return }

        let descriptor = FetchDescriptor<SDProject>(
            predicate: #Predicate<SDProject> { $0.remoteAppId == nil }
        )
        guard let unsynced = try? modelContext.fetch(descriptor), !unsynced.isEmpty else { return }

        var syncedCount = 0
        for project in unsynced {
            if await syncOneProject(project) {
                syncedCount += 1
            }
        }

        if syncedCount > 0 {
            try? modelContext.save()
            // UI に反映するため自分の apps 一覧を再 fetch
            if let refreshed = try? await appRepository.fetchMyApps() {
                apps = refreshed
            }
        }
    }

    /// 戻り値: sync 成功で `remoteAppId` がセットされたら true。
    private func syncOneProject(_ project: SDProject) async -> Bool {
        do {
            var iconURLString: String?
            if let iconData = project.iconImageData {
                let url = try await appRepository.uploadAppIcon(
                    imageData: iconData,
                    contentType: "image/jpeg"
                )
                iconURLString = url.absoluteString
            }

            let insertDTO = AppInsertDTO(
                name: project.name,
                description: project.appDescription.isEmpty ? nil : project.appDescription,
                iconUrl: iconURLString,
                screenshots: nil,
                platform: project.platforms.first ?? "other",
                appUrl: nil,
                storeUrl: project.storeURL,
                githubUrl: project.githubURL,
                status: project.statusRaw,
                category: nil
            )
            let inserted = try await appRepository.insertApp(insertDTO)
            project.remoteAppId = inserted.id
            project.remoteIconUrl = iconURLString
            return true
        } catch {
            print("[ProfileViewModel] syncOneProject failed: \(error.localizedDescription)")
            return false
        }
    }

    /// `WeeklyStats.dailyTotals` を曜日ラベル付き時間に変換。
    /// locale 依存せず固定ラベル (月〜日) を返す。チャートの縦軸は時間単位。
    private static func buildWeeklyHours(from weekly: WeeklyStats) -> [(day: String, hours: Double)] {
        let labels = ["weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat", "weekday.sun"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // Monday
        let sorted = weekly.dailyTotals.sorted { $0.date < $1.date }
        return sorted.enumerated().map { idx, stats in
            let label = idx < labels.count ? labels[idx] : ""
            return (label, Double(stats.totalMinutes) / 60.0)
        }
    }

    // MARK: - Liked / Bookmarked Lists (自分のプロフィールのみ)

    /// 「いいね」タブ初回表示時 / pull-to-refresh 時に呼ぶ。自分のプロフィール以外では no-op。
    func loadLikedPosts(force: Bool = false) async {
        guard isMyProfile, !isLoadingLiked else { return }
        if !force && hasLoadedLikedOnce { return }
        isLoadingLiked = true
        defer { isLoadingLiked = false }
        do {
            likedPosts = try await likeRepository.fetchLiked(cursor: nil, limit: AppConfig.feedPageSize)
            hasLoadedLikedOnce = true
        } catch {
            // silent: keep previous list
        }
    }

    func loadBookmarkedPosts(force: Bool = false) async {
        guard isMyProfile, !isLoadingBookmarked else { return }
        if !force && hasLoadedBookmarkedOnce { return }
        isLoadingBookmarked = true
        defer { isLoadingBookmarked = false }
        do {
            bookmarkedPosts = try await bookmarkRepository.fetchBookmarked(cursor: nil, limit: AppConfig.feedPageSize)
            hasLoadedBookmarkedOnce = true
        } catch {
            // silent
        }
    }

    /// PostCardView で unlike された時に即リストから消す (user 合意「取り消し時即時リストから消える」)。
    func removeLikedPost(id: UUID) {
        likedPosts.removeAll { $0.id == id }
    }

    func removeBookmarkedPost(id: UUID) {
        bookmarkedPosts.removeAll { $0.id == id }
    }

    // MARK: - Actions

    func toggleFollow() async {
        guard let userId = targetUserId else { return }

        // オプティミスティックUI
        isFollowing.toggle()
        followerCount += isFollowing ? 1 : -1

        do {
            if isFollowing {
                try await followRepository.follow(userId: userId)
            } else {
                try await followRepository.unfollow(userId: userId)
            }
        } catch {
            // ロールバック
            isFollowing.toggle()
            followerCount += isFollowing ? 1 : -1
        }
    }
}
