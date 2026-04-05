import Foundation

/// Supabase `profiles` テーブル対応DTO
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
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// プロフィール更新用DTO (部分更新)
struct ProfileUpdateDTO: Codable, Sendable {
    var handle: String?
    var displayName: String?
    var avatarUrl: String?
    var ageGroup: String?
    var gender: String?
    var occupation: String?
    var workType: String?
    var incomeStatus: String?
    var experienceYears: String?
    var bio: String?
    var notificationEnabled: Bool?
    var onboardingCompleted: Bool?

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
    }
}
