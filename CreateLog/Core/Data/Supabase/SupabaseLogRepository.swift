import Foundation
import Supabase

/// LogRepositoryProtocol の Supabase実装
final class SupabaseLogRepository: LogRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchLogs(for date: Date) async throws -> [LogDTO] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: startOfDay)
        let endStr = formatter.string(from: endOfDay)

        let result: [LogDTO] = try await client
            .from("logs")
            .select()
            .gte("started_at", value: startStr)
            .lt("started_at", value: endStr)
            .order("started_at", ascending: false)
            .execute()
            .value

        return result
    }

    func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO] {
        let formatter = ISO8601DateFormatter()
        let startStr = formatter.string(from: start)
        let endStr = formatter.string(from: end)

        let result: [LogDTO] = try await client
            .from("logs")
            .select()
            .gte("started_at", value: startStr)
            .lte("started_at", value: endStr)
            .order("started_at", ascending: false)
            .execute()
            .value

        return result
    }

    func insertLog(_ log: LogInsertDTO) async throws -> LogDTO {
        let result: LogDTO = try await client
            .from("logs")
            .insert(log)
            .select()
            .single()
            .execute()
            .value

        return result
    }

    func deleteLog(id: UUID) async throws {
        try await client
            .from("logs")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
