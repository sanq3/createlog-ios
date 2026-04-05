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

    enum CodingKeys: String, CodingKey {
        case id, type, message
        case userId = "user_id"
        case actorId = "actor_id"
        case postId = "post_id"
        case isRead = "is_read"
        case createdAt = "created_at"
        case actorDisplayName = "actor_display_name"
        case actorHandle = "actor_handle"
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
        actorDisplayName = try container.decodeIfPresent(String.self, forKey: .actorDisplayName)
        actorHandle = try container.decodeIfPresent(String.self, forKey: .actorHandle)
    }
}
