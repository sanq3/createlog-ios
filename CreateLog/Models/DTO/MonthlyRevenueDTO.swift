import Foundation

/// Supabase `monthly_revenues` テーブル対応 DTO
///
/// T4 (2026-04-12): 月次収益記録 (プロフィール表示で使用)
struct MonthlyRevenueDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    let year: Int
    let month: Int
    /// numeric(10,2) を Decimal として受ける
    let revenue: Decimal
    let note: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case year
        case month
        case revenue
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 月次収益 insert/upsert payload
struct MonthlyRevenueUpsertDTO: Codable, Sendable {
    let userId: UUID
    let year: Int
    let month: Int
    let revenue: Decimal
    let note: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case year
        case month
        case revenue
        case note
    }
}
