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

    func updateLog(_ update: LogUpdateDTO) async throws -> LogDTO {
        // PostgREST 部分更新: nil でないフィールドのみ送信される (encodeIfPresent で nil 省略)。
        // `id` は row identity のため body から除外し、URL eq filter で対象を特定する。
        let wire = LogUpdateWire(from: update)
        let result: LogDTO = try await client
            .from("logs")
            .update(wire)
            .eq("id", value: update.id.uuidString)
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

/// PostgREST update body 用の wire format (id を含まない)。
private struct LogUpdateWire: Encodable {
    var title: String?
    var categoryId: UUID?
    var startedAt: Date?
    var endedAt: Date?
    var durationMinutes: Int?
    var memo: String?
    var isTimer: Bool?

    enum CodingKeys: String, CodingKey {
        case title, memo
        case categoryId = "category_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case durationMinutes = "duration_minutes"
        case isTimer = "is_timer"
    }

    init(from update: LogUpdateDTO) {
        self.title = update.title
        self.categoryId = update.categoryId
        self.startedAt = update.startedAt
        self.endedAt = update.endedAt
        self.durationMinutes = update.durationMinutes
        self.memo = update.memo
        self.isTimer = update.isTimer
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(durationMinutes, forKey: .durationMinutes)
        try container.encodeIfPresent(memo, forKey: .memo)
        try container.encodeIfPresent(isTimer, forKey: .isTimer)
    }
}
