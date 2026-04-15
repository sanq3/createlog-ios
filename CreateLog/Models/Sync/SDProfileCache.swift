import Foundation
import SwiftData

/// Remote `profiles` テーブルの local cache。Offline-first + SWR (Stale-While-Revalidate) 用。
///
/// ## 役割
/// プロフィール画面を開いた瞬間の "一瞬の空表示 (flicker)" を消すために、remote fetch 前に
/// 同期的に前回取得値を View に供給する。業界標準 (Bluesky `placeholderData`, Instagram SQLite
/// warm tier, Threads cached profile precache) の iOS 版。
///
/// ## 使用位置
/// - `OfflineFirstProfileRepository.fetchMyProfile / fetchProfile` の cache fallback + upsert
/// - `OfflineFirstProfileRepository.cachedMyProfile / cachedProfile(userId:)` が View init で同期 read
///   - 自分の profile 識別は `UserDefaults("cl.lastKnownMyProfileId")` に cache 書き込み時の
///     `profile.id` を記録する方式 (機密でない PK のため Keychain 不要)
///
/// ## lightweight migration 要件
/// 全非 optional フィールドに default 値を持たせる (SwiftData lightweight migration 要件)。
/// `[String]` 等の複合型は `Data` に JSON encode して保持 (migration 耐性)。
///
/// ## 設計メモ
/// - `ProfileDTO` 全 field を coverage (読み取り専用 count 含む) → View からの全 field アクセスに耐える
/// - `isDeleted` / `updatedAtRemote` / `syncedAt` は既存 `SDPostCache` 等と同型
/// - `syncStatusRaw` は将来の conflict resolution / queued profile edit の `syncStatus` 識別用
@Model
final class SDProfileCache {
    // MARK: - Primary identity

    /// Remote `profiles.id` (UUID PK, `auth.users.id` と同じ値)。
    @Attribute(.unique) var remoteId: UUID = UUID()

    // MARK: - Core fields (ProfileDTO coverage)

    var email: String = ""
    var handle: String? = nil
    var displayName: String? = nil
    var avatarUrl: String? = nil
    var role: String = "developer"
    var ageGroup: String? = nil
    var gender: String? = nil
    var occupation: String? = nil
    var workType: String? = nil
    var incomeStatus: String? = nil
    var experienceYears: String? = nil
    var bio: String? = nil
    var timezone: String = "Asia/Tokyo"
    var notificationEnabled: Bool = true
    var onboardingCompleted: Bool = false

    // MARK: - T4-B SNS fields

    var nickname: String? = nil
    var visibility: String = "public"
    var followersCount: Int = 0
    var followingCount: Int = 0
    var postsCount: Int = 0
    var githubUrl: String? = nil
    var xUrl: String? = nil
    var websiteUrl: String? = nil

    // MARK: - T4-B status fields

    var currentStatus: String? = nil
    var statusType: String? = nil
    var statusProject: String? = nil
    var statusStartedAt: Date? = nil
    var statusUpdatedAt: Date? = nil

    // MARK: - Remote timestamps (ProfileDTO required)

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - Cache metadata (offline-first infra 共通)

    /// local cache の最終更新時刻 (SWR staleTime 判定用)。
    var syncedAt: Date = Date()

    /// Tombstone フラグ。account 削除等の propagation 用 (MVP では未使用、将来拡張)。
    var isDeleted: Bool = false

    /// Remote 側の `updated_at` snapshot。LWW conflict resolution 用 (ProfileDTO.updatedAt と同値で初期化)。
    var updatedAtRemote: Date = Date()

    /// Sync 状態識別子 (`SyncStatus.rawValue` 相当)。既存 SD*Cache と同型だが MVP では `synced` 固定。
    var syncStatusRaw: String = "synced"

    init(
        remoteId: UUID,
        email: String,
        handle: String? = nil,
        displayName: String? = nil,
        avatarUrl: String? = nil,
        role: String = "developer",
        ageGroup: String? = nil,
        gender: String? = nil,
        occupation: String? = nil,
        workType: String? = nil,
        incomeStatus: String? = nil,
        experienceYears: String? = nil,
        bio: String? = nil,
        timezone: String = "Asia/Tokyo",
        notificationEnabled: Bool = true,
        onboardingCompleted: Bool = false,
        nickname: String? = nil,
        visibility: String = "public",
        followersCount: Int = 0,
        followingCount: Int = 0,
        postsCount: Int = 0,
        githubUrl: String? = nil,
        xUrl: String? = nil,
        websiteUrl: String? = nil,
        currentStatus: String? = nil,
        statusType: String? = nil,
        statusProject: String? = nil,
        statusStartedAt: Date? = nil,
        statusUpdatedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        updatedAtRemote: Date = Date(),
        syncStatusRaw: String = "synced"
    ) {
        self.remoteId = remoteId
        self.email = email
        self.handle = handle
        self.displayName = displayName
        self.avatarUrl = avatarUrl
        self.role = role
        self.ageGroup = ageGroup
        self.gender = gender
        self.occupation = occupation
        self.workType = workType
        self.incomeStatus = incomeStatus
        self.experienceYears = experienceYears
        self.bio = bio
        self.timezone = timezone
        self.notificationEnabled = notificationEnabled
        self.onboardingCompleted = onboardingCompleted
        self.nickname = nickname
        self.visibility = visibility
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.postsCount = postsCount
        self.githubUrl = githubUrl
        self.xUrl = xUrl
        self.websiteUrl = websiteUrl
        self.currentStatus = currentStatus
        self.statusType = statusType
        self.statusProject = statusProject
        self.statusStartedAt = statusStartedAt
        self.statusUpdatedAt = statusUpdatedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
        self.updatedAtRemote = updatedAtRemote
        self.syncStatusRaw = syncStatusRaw
    }
}
