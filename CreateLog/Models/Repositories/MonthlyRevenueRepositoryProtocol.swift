import Foundation

/// 月次収益 Repository
///
/// T4 (2026-04-12): プロフィール表示で使用 (年次収益グラフ等)
protocol MonthlyRevenueRepositoryProtocol: Sendable {
    /// 指定 user の年次 revenue を取得 (year = nil なら全期間)
    func fetchRevenues(userId: UUID, year: Int?) async throws -> [MonthlyRevenueDTO]
    /// (year, month) の upsert (UNIQUE 制約で自動的に update or insert)
    func upsertRevenue(_ upsert: MonthlyRevenueUpsertDTO) async throws -> MonthlyRevenueDTO
    /// revenue レコード削除
    func deleteRevenue(id: UUID) async throws
}
