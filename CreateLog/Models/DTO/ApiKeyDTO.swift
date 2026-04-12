import Foundation

/// Supabase `api_keys` テーブル対応 DTO
///
/// T4 (2026-04-12): エディタ拡張・デスクトップアプリの認証用 API key
/// - `keyHash` は SHA-256 hash のみ、raw key は server-side で生成
/// - iOS 側は list / revoke のみサポート、create は Edge Function 必須 (security)
struct ApiKeyDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let name: String
    /// SHA-256 hash、raw key は DB に保存されない
    let keyHash: String
    /// 最初の数文字 (UI で "ck_abc..." のように表示)
    let keyPrefix: String
    let lastUsedAt: Date?
    let expiresAt: Date?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case keyHash = "key_hash"
        case keyPrefix = "key_prefix"
        case lastUsedAt = "last_used_at"
        case expiresAt = "expires_at"
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
