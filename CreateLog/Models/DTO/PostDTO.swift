import Foundation

/// Supabase `posts` テーブル対応DTO
struct PostDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    var content: String
    /// 画像配列。`posts.media_urls` (jsonb) に保存される。詳細は `PostMediaItem` 参照。
    /// 2026-04-16: `[String]` → `[PostMediaItem]` に変更 (Phase 1/2/3 対応 schema)。
    var media: [PostMediaItem]
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
        case media = "media_urls"
        case likesCount = "likes_count"
        case repostsCount = "reposts_count"
        case commentsCount = "comments_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case authorDisplayName = "author_display_name"
        case authorHandle = "author_handle"
        case authorAvatarUrl = "author_avatar_url"
    }

    /// JOIN で embed される `profiles` レコード。`select("*, author:profiles!posts_user_id_fkey(...)")`
    /// で返されるネスト object を decode するための専用キー。`author` は DB カラムではなく
    /// Supabase の select で一時的に紐づけた alias なので `CodingKeys` には含めない
    /// (含めると Encodable auto-synthesize が壊れる)。
    private enum ExtraDecodeKeys: String, CodingKey {
        case author
    }

    enum AuthorCodingKeys: String, CodingKey {
        case handle
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        media = try container.decodeIfPresent([PostMediaItem].self, forKey: .media) ?? []
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        repostsCount = try container.decodeIfPresent(Int.self, forKey: .repostsCount) ?? 0
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "public"
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // 2026-04-16: JOIN 応答 (nested `author`) 優先、RPC flat 応答 (author_*) fallback。
        // Bluesky feed precache pattern の iOS 版 — feed 取得時に author basic を持ち帰る。
        let extraContainer = try decoder.container(keyedBy: ExtraDecodeKeys.self)
        if let authorContainer = try? extraContainer.nestedContainer(keyedBy: AuthorCodingKeys.self, forKey: .author) {
            authorHandle = try? authorContainer.decodeIfPresent(String.self, forKey: .handle)
            authorDisplayName = try? authorContainer.decodeIfPresent(String.self, forKey: .displayName)
            authorAvatarUrl = try? authorContainer.decodeIfPresent(String.self, forKey: .avatarUrl)
        } else {
            authorDisplayName = try container.decodeIfPresent(String.self, forKey: .authorDisplayName)
            authorHandle = try container.decodeIfPresent(String.self, forKey: .authorHandle)
            authorAvatarUrl = try container.decodeIfPresent(String.self, forKey: .authorAvatarUrl)
        }
    }
}

/// 投稿作成用DTO
struct PostInsertDTO: Codable, Sendable {
    let content: String
    /// 画像メタデータ配列。空配列なら画像なし。client 側で 2 サイズ upload 後に埋める。
    var media: [PostMediaItem]
    var visibility: String

    enum CodingKeys: String, CodingKey {
        case content, visibility
        case media = "media_urls"
    }

    init(content: String, media: [PostMediaItem] = [], visibility: String = "public") {
        self.content = content
        self.media = media
        self.visibility = visibility
    }
}
