import Foundation

/// プロフィール画面のViewModel
@MainActor @Observable
final class ProfileViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let appRepository: any AppRepositoryProtocol
    @ObservationIgnored private let followRepository: any FollowRepositoryProtocol
    @ObservationIgnored private let statsRepository: any StatsRepositoryProtocol

    // MARK: - State

    var profile: ProfileDTO?
    var apps: [AppDTO] = []
    var followerCount = 0
    var followingCount = 0
    var isFollowing = false
    var totalMinutes = 0
    var streak = 0
    var isLoading = false
    var errorMessage: String?

    /// 自分のプロフィールかどうか
    let isMyProfile: Bool
    private let targetUserId: UUID?

    // MARK: - Init

    init(
        profileRepository: any ProfileRepositoryProtocol,
        appRepository: any AppRepositoryProtocol,
        followRepository: any FollowRepositoryProtocol,
        statsRepository: any StatsRepositoryProtocol,
        userId: UUID? = nil
    ) {
        self.profileRepository = profileRepository
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
            if let userId = targetUserId {
                profile = try await profileRepository.fetchProfile(userId: userId)
                apps = try await appRepository.fetchApps(userId: userId)
                let counts = try await followRepository.fetchCounts(userId: userId)
                followerCount = counts.followers
                followingCount = counts.following
                isFollowing = try await followRepository.isFollowing(userId: userId)
            } else {
                profile = try await profileRepository.fetchMyProfile()
                apps = try await appRepository.fetchMyApps()
                if let myId = profile?.id {
                    let counts = try await followRepository.fetchCounts(userId: myId)
                    followerCount = counts.followers
                    followingCount = counts.following
                }
                totalMinutes = try await statsRepository.fetchCumulativeMinutes()
            }
        } catch {
            errorMessage = "プロフィールの読み込みに失敗しました"
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
