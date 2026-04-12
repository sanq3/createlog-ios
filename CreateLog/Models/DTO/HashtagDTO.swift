import Foundation

/// Supabase `hashtags` テーブル対応 DTO
///
/// T4 (2026-04-12): ハッシュタグマスター (lowercase CHECK 制約あり)
struct HashtagDTO: Codable, Sendable {
    let id: UUID
    /// lowercase 強制 (CHECK 制約)
    let name: String
    let postCount: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case postCount = "post_count"
        case createdAt = "created_at"
    }
}
