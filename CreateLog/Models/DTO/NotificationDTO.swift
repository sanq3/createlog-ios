import Foundation

/// Supabase `notifications` テーブル対応DTO
struct NotificationDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    var type: String
    var actorId: UUID?
    var postId: UUID?
    var message: String?
    var isRead: Bool
    let createdAt: Date

    var actorDisplayName: String?
    var actorHandle: String?
    /// JOIN で取得する actor の avatar URL。 `notifications` テーブルに column 無し、
    /// nested `actor:profiles!FK(avatar_url)` 経由で取得。通知画面の avatar 表示用。
    var actorAvatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, type, message
        case userId = "user_id"
        case actorId = "actor_id"
        case postId = "post_id"
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    /// JOIN 応答の nested actor を decode するためのキー (`select("*, actor:profiles!FK(...)")` 前提)。
    /// PostDTO と同じ pattern。
    private enum ExtraDecodeKeys: String, CodingKey {
        case actor
    }

    enum ActorCodingKeys: String, CodingKey {
        case handle
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "system"
        actorId = try container.decodeIfPresent(UUID.self, forKey: .actorId)
        postId = try container.decodeIfPresent(UUID.self, forKey: .postId)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)

        // 2026-04-20: JOIN 応答 (nested `actor`) 優先 decode。
        // 従来の flat `actor_display_name` / `actor_handle` column は DB に存在しないため
        // 常に nil になり、"someone" fallback 表示されていた既存 bug を修正。
        let extraContainer = try decoder.container(keyedBy: ExtraDecodeKeys.self)
        if let actorContainer = try? extraContainer.nestedContainer(keyedBy: ActorCodingKeys.self, forKey: .actor) {
            actorHandle = try? actorContainer.decodeIfPresent(String.self, forKey: .handle)
            actorDisplayName = try? actorContainer.decodeIfPresent(String.self, forKey: .displayName)
            actorAvatarUrl = try? actorContainer.decodeIfPresent(String.self, forKey: .avatarUrl)
        } else {
            actorDisplayName = nil
            actorHandle = nil
            actorAvatarUrl = nil
        }
    }
}
