import Foundation

/// Supabase `logs` テーブル対応DTO
struct LogDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    var title: String
    var categoryId: UUID
    var startedAt: Date
    var endedAt: Date
    var durationMinutes: Int
    var memo: String?
    var isTimer: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, memo
        case userId = "user_id"
        case categoryId = "category_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case isTimer = "is_timer"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "その他"
        categoryId = try container.decode(UUID.self, forKey: .categoryId)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decode(Date.self, forKey: .endedAt)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 0
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        isTimer = try container.decodeIfPresent(Bool.self, forKey: .isTimer) ?? false
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// ログ作成用DTO
struct LogInsertDTO: Codable, Sendable {
    let title: String
    let categoryId: UUID
    let startedAt: Date
    let endedAt: Date
    let durationMinutes: Int
    var memo: String?
    var isTimer: Bool

    enum CodingKeys: String, CodingKey {
        case title, memo
        case categoryId = "category_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case isTimer = "is_timer"
    }
}
