import Foundation

/// Supabase `bookmarks` テーブル対応 DTO。自分のブックマークのみ RLS で閲覧可能。
struct BookmarkDTO: Codable, Sendable, Identifiable {
    let id: UUID
    let userId: UUID
    let postId: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case postId = "post_id"
        case createdAt = "created_at"
    }
}
