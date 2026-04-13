import Foundation

/// プロフィール画面のViewModel
@MainActor @Observable
final class ProfileViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let postRepository: any PostRepositoryProtocol
    @ObservationIgnored private let appRepository: any AppRepositoryProtocol
    @ObservationIgnored private let followRepository: any FollowRepositoryProtocol
    @ObservationIgnored private let statsRepository: any StatsRepositoryProtocol

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
    var isLoading = false
    var errorMessage: String?

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
        userId: UUID? = nil
    ) {
        self.profileRepository = profileRepository
        self.postRepository = postRepository
        self.appRepository = appRepository
        self.followRepository = followRepository
        self.statsRepository = statsRepository
        self.targetUserId = userId
        self.isMyProfile = userId == nil
    }

    // MARK: - Data Loading

    func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

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

    /// `WeeklyStats.dailyTotals` を曜日ラベル付き時間に変換。
    /// locale 依存せず固定ラベル (月〜日) を返す。チャートの縦軸は時間単位。
    private static func buildWeeklyHours(from weekly: WeeklyStats) -> [(day: String, hours: Double)] {
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2  // Monday
        let sorted = weekly.dailyTotals.sorted { $0.date < $1.date }
        return sorted.enumerated().map { idx, stats in
            let label = idx < labels.count ? labels[idx] : ""
            return (label, Double(stats.totalMinutes) / 60.0)
        }
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
