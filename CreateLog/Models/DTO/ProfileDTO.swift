import Foundation

/// Supabase `profiles` テーブル対応DTO
///
/// T4-B (2026-04-12): SNS/status 13 カラムを追加。
/// - 読み取り専用 count (followers/following/posts) は trigger で更新されるため
///   ProfileUpdateDTO には含めない。
/// - `visibility` は NOT NULL default 'public' (remote DDL)。decode 時は fallback 'public'。
/// - counts は NOT NULL default 0。decode 時は fallback 0。
struct ProfileDTO: Codable, Sendable {
    let id: UUID
    let email: String
    var handle: String?
    var displayName: String?
    var avatarUrl: String?
    var role: String
    var ageGroup: String?
    var gender: String?
    var occupation: String?
    var workType: String?
    var incomeStatus: String?
    var experienceYears: String?
    var bio: String?
    var timezone: String
    var notificationEnabled: Bool
    var onboardingCompleted: Bool

    // MARK: - T4-B: SNS fields
    var nickname: String?
    var visibility: String
    var followersCount: Int
    var followingCount: Int
    var postsCount: Int
    var githubUrl: String?
    var xUrl: String?
    var websiteUrl: String?

    // MARK: - T4-B: status fields
    var currentStatus: String?
    var statusType: String?
    var statusProject: String?
    var statusStartedAt: Date?
    var statusUpdatedAt: Date?

    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email, handle, role, bio, timezone, gender, occupation
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case ageGroup = "age_group"
        case workType = "work_type"
        case incomeStatus = "income_status"
        case experienceYears = "experience_years"
        case notificationEnabled = "notification_enabled"
        case onboardingCompleted = "onboarding_completed"
        case nickname
        case visibility
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case postsCount = "posts_count"
        case githubUrl = "github_url"
        case xUrl = "x_url"
        case websiteUrl = "website_url"
        case currentStatus = "current_status"
        case statusType = "status_type"
        case statusProject = "status_project"
        case statusStartedAt = "status_started_at"
        case statusUpdatedAt = "status_updated_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        handle = try container.decodeIfPresent(String.self, forKey: .handle)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        avatarUrl = try container.decodeIfPresent(String.self, forKey: .avatarUrl)
        role = try container.decodeIfPresent(String.self, forKey: .role) ?? "developer"
        ageGroup = try container.decodeIfPresent(String.self, forKey: .ageGroup)
        gender = try container.decodeIfPresent(String.self, forKey: .gender)
        occupation = try container.decodeIfPresent(String.self, forKey: .occupation)
        workType = try container.decodeIfPresent(String.self, forKey: .workType)
        incomeStatus = try container.decodeIfPresent(String.self, forKey: .incomeStatus)
        experienceYears = try container.decodeIfPresent(String.self, forKey: .experienceYears)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        timezone = try container.decodeIfPresent(String.self, forKey: .timezone) ?? "Asia/Tokyo"
        notificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationEnabled) ?? true
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false

        // T4-B: SNS fields
        nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        githubUrl = try container.decodeIfPresent(String.self, forKey: .githubUrl)
        xUrl = try container.decodeIfPresent(String.self, forKey: .xUrl)
        websiteUrl = try container.decodeIfPresent(String.self, forKey: .websiteUrl)

        // T4-B: status fields
        currentStatus = try container.decodeIfPresent(String.self, forKey: .currentStatus)
        statusType = try container.decodeIfPresent(String.self, forKey: .statusType)
        statusProject = try container.decodeIfPresent(String.self, forKey: .statusProject)
        statusStartedAt = try container.decodeIfPresent(Date.self, forKey: .statusStartedAt)
        statusUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .statusUpdatedAt)

        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// プロフィール更新用DTO (部分更新)
///
/// T4-B (2026-04-12):
/// - 全プロパティに `= nil` default を付与 (既存 12 + 新 10 = 22 field)。
///   既存の 12-arg 呼出 (ProfileEditViewModel.save L121) は named-call なので
///   引き続きコンパイル通過する。
/// - counts (followers/following/posts) は DB trigger で更新されるため含めない。
struct ProfileUpdateDTO: Codable, Sendable {
    var handle: String? = nil
    var displayName: String? = nil
    var avatarUrl: String? = nil
    var ageGroup: String? = nil
    var gender: String? = nil
    var occupation: String? = nil
    var workType: String? = nil
    var incomeStatus: String? = nil
    var experienceYears: String? = nil
    var bio: String? = nil
    var notificationEnabled: Bool? = nil
    var onboardingCompleted: Bool? = nil

    // MARK: - T4-B: SNS fields (partial update)
    var nickname: String? = nil
    var visibility: String? = nil
    var githubUrl: String? = nil
    var xUrl: String? = nil
    var websiteUrl: String? = nil

    // MARK: - T4-B: status fields (partial update)
    var currentStatus: String? = nil
    var statusType: String? = nil
    var statusProject: String? = nil
    var statusStartedAt: Date? = nil
    var statusUpdatedAt: Date? = nil

    enum CodingKeys: String, CodingKey {
        case handle, bio, gender, occupation
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
        case ageGroup = "age_group"
        case workType = "work_type"
        case incomeStatus = "income_status"
        case experienceYears = "experience_years"
        case notificationEnabled = "notification_enabled"
        case onboardingCompleted = "onboarding_completed"
        case nickname
        case visibility
        case githubUrl = "github_url"
        case xUrl = "x_url"
        case websiteUrl = "website_url"
        case currentStatus = "current_status"
        case statusType = "status_type"
        case statusProject = "status_project"
        case statusStartedAt = "status_started_at"
        case statusUpdatedAt = "status_updated_at"
    }
}
