import Foundation

/// Supabase `apps` テーブル対応DTO (ポートフォリオ/マイプロダクト)
struct AppDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    var name: String
    var description: String?
    var iconUrl: String?
    var screenshots: [String]
    var platform: String
    var appUrl: String?
    var storeUrl: String?
    var githubUrl: String?
    var status: String
    var category: String?
    var avgRating: Double?
    var reviewCount: Int
    let createdAt: Date
    let updatedAt: Date
    /// Discover 新着順ソート用 (user が「更新を公開」を押した時だけ更新される)。
    /// migration 20260417000000 で追加、既存行は created_at と同値に backfill。
    let lastBumpedAt: Date

    // JOINで取得する作者 basic (Discover 混合 feed で Project 表示に使う)。PostDTO と同パターン。
    var authorDisplayName: String?
    var authorHandle: String?
    var authorAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, description, screenshots, platform, category, status
        case userId = "user_id"
        case iconUrl = "icon_url"
        case appUrl = "app_url"
        case storeUrl = "store_url"
        case githubUrl = "github_url"
        case avgRating = "avg_rating"
        case reviewCount = "review_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastBumpedAt = "last_bumped_at"
    }

    /// JOIN で embed される `profiles` alias。`CodingKeys` に含めると Encodable auto-synth が壊れるので分離。
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
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        iconUrl = try container.decodeIfPresent(String.self, forKey: .iconUrl)
        screenshots = try container.decodeIfPresent([String].self, forKey: .screenshots) ?? []
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "other"
        appUrl = try container.decodeIfPresent(String.self, forKey: .appUrl)
        storeUrl = try container.decodeIfPresent(String.self, forKey: .storeUrl)
        githubUrl = try container.decodeIfPresent(String.self, forKey: .githubUrl)
        status = try container.decodeIfPresent(String.self, forKey: .status) ?? "draft"
        category = try container.decodeIfPresent(String.self, forKey: .category)
        avgRating = try container.decodeIfPresent(Double.self, forKey: .avgRating)
        reviewCount = try container.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // migration 前の古いレコード / bucket 同期遅延で欠損する場合は created_at にフォールバック
        lastBumpedAt = try container.decodeIfPresent(Date.self, forKey: .lastBumpedAt) ?? createdAt

        // JOIN 応答の nested `author` を optional で decode (fetchAllApps 以外ではスキップ)
        let extraContainer = try decoder.container(keyedBy: ExtraDecodeKeys.self)
        if let authorContainer = try? extraContainer.nestedContainer(keyedBy: AuthorCodingKeys.self, forKey: .author) {
            authorHandle = try? authorContainer.decodeIfPresent(String.self, forKey: .handle)
            authorDisplayName = try? authorContainer.decodeIfPresent(String.self, forKey: .displayName)
            authorAvatarUrl = try? authorContainer.decodeIfPresent(String.self, forKey: .avatarUrl)
        } else {
            authorDisplayName = nil
            authorHandle = nil
            authorAvatarUrl = nil
        }
    }
}

/// アプリ登録用DTO
struct AppInsertDTO: Codable, Sendable {
    let name: String
    var description: String?
    var iconUrl: String?
    var screenshots: [String]?
    var platform: String
    var appUrl: String?
    var storeUrl: String?
    var githubUrl: String?
    var status: String
    var category: String?

    enum CodingKeys: String, CodingKey {
        case name, description, screenshots, platform, status, category
        case iconUrl = "icon_url"
        case appUrl = "app_url"
        case storeUrl = "store_url"
        case githubUrl = "github_url"
    }
}
