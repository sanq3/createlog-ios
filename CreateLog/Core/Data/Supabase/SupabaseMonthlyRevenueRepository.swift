import Foundation
import Supabase

/// MonthlyRevenueRepositoryProtocol の Supabase 実装
///
/// T4 (2026-04-12): プロフィール表示用の月次収益
final class SupabaseMonthlyRevenueRepository: MonthlyRevenueRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchRevenues(userId: UUID, year: Int?) async throws -> [MonthlyRevenueDTO] {
        let query = client
            .from("monthly_revenues")
            .select()
            .eq("user_id", value: userId.uuidString)

        if let year {
            let result: [MonthlyRevenueDTO] = try await query
                .eq("year", value: year)
                .order("month", ascending: true)
                .execute()
                .value
            return result
        }

        let result: [MonthlyRevenueDTO] = try await query
            .order("year", ascending: false)
            .order("month", ascending: false)
            .execute()
            .value
        return result
    }

    func upsertRevenue(_ upsert: MonthlyRevenueUpsertDTO) async throws -> MonthlyRevenueDTO {
        // UNIQUE(user_id, year, month) 前提
        let result: MonthlyRevenueDTO = try await client
            .from("monthly_revenues")
            .upsert(upsert, onConflict: "user_id,year,month")
            .select()
            .single()
            .execute()
            .value
        return result
    }

    func deleteRevenue(id: UUID) async throws {
        try await client
            .from("monthly_revenues")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
