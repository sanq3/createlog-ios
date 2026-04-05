import Foundation

/// Supabase `categories` テーブル対応DTO
struct CategoryDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID?
    var name: String
    var color: String
    var icon: String?
    var isActive: Bool
    var isDefault: Bool
    var displayOrder: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name, color, icon
        case userId = "user_id"
        case isActive = "is_active"
        case isDefault = "is_default"
        case displayOrder = "display_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decodeIfPresent(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#808080"
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

/// カテゴリ作成用DTO
struct CategoryInsertDTO: Codable, Sendable {
    let name: String
    let color: String
    var icon: String?
    var displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case name, color, icon
        case displayOrder = "display_order"
    }
}
