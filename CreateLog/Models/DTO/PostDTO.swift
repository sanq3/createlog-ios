import Foundation

/// Supabase `posts` テーブル対応DTO
struct PostDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    var content: String
    var mediaUrls: [String]
    var likesCount: Int
    var repostsCount: Int
    var commentsCount: Int
    var visibility: String
    let createdAt: Date
    let updatedAt: Date

    // JOINで取得するプロフィール情報 (オプション)
    var authorDisplayName: String?
    var authorHandle: String?
    var authorAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, content, visibility
        case userId = "user_id"
        case mediaUrls = "media_urls"
        case likesCount = "likes_count"
        case repostsCount = "reposts_count"
        case commentsCount = "comments_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorDisplayName = "author_display_name"
        case authorHandle = "author_handle"
        case authorAvatarUrl = "author_avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        mediaUrls = try container.decodeIfPresent([String].self, forKey: .mediaUrls) ?? []
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        repostsCount = try container.decodeIfPresent(Int.self, forKey: .repostsCount) ?? 0
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
        authorHandle = try container.decodeIfPresent(String.self, forKey: .authorHandle)
        authorAvatarUrl = try container.decodeIfPresent(String.self, forKey: .authorAvatarUrl)
    }
}

/// 投稿作成用DTO
struct PostInsertDTO: Codable, Sendable {
    let content: String
    var mediaUrls: [String]?
    var visibility: String

    enum CodingKeys: String, CodingKey {
        case content, visibility
        case mediaUrls = "media_urls"
    }
}
