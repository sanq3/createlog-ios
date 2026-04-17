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

/// ログ更新用DTO (T7b 部分更新)
///
/// queue payload に Codable 経由で保存され、`LogFlushExecutor.execute` で復元される。
/// `id` は payload に含まれ、PostgREST 送信時は URL eq filter に渡される。
/// `updatedAt` は trigger で自動更新されるため含めない。
///
/// ## Encode 戦略
/// `encodeIfPresent` で nil フィールドを完全にスキップする (default Codable は nil を null として encode するため)。
/// queue 側でも wire 側でも nil を送らず、両方のフォーマットを兼用する。
/// PostgREST `update(...)` では「キー存在 = 上書き対象」のため、不要フィールドは encode 自体しない。
struct LogUpdateDTO: Codable, Sendable {
    let id: UUID
    var title: String?
    var categoryId: UUID?
    var startedAt: Date?
    var endedAt: Date?
    var durationMinutes: Int?
    var memo: String?
    var isTimer: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, memo
        case categoryId = "category_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case isTimer = "is_timer"
    }

    init(
        id: UUID,
        title: String? = nil,
        categoryId: UUID? = nil,
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        durationMinutes: Int? = nil,
        memo: String? = nil,
        isTimer: Bool? = nil
    ) {
        self.id = id
        self.title = title
        self.categoryId = categoryId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMinutes = durationMinutes
        self.memo = memo
        self.isTimer = isTimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        startedAt = try container.decodeIfPresent(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        durationMinutes = try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
        memo = try container.decodeIfPresent(String.self, forKey: .memo)
        isTimer = try container.decodeIfPresent(Bool.self, forKey: .isTimer)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encodeIfPresent(isTimer, forKey: .isTimer)
    }
}
