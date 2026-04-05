import Foundation
import Supabase

/// StatsRepositoryProtocol の Supabase実装
final class SupabaseStatsRepository: StatsRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchDailyStats(for date: Date) async throws -> DailyStats {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return DailyStats(date: date, totalMinutes: 0, categoryBreakdown: [])
        }

        let logs = try await fetchLogs(from: startOfDay, to: endOfDay)
        return buildDailyStats(date: date, logs: logs)
    }

    func fetchWeeklyStats(containing date: Date) async throws -> WeeklyStats {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return WeeklyStats(weekStart: date, dailyTotals: [], totalMinutes: 0, previousWeekMinutes: nil)
        }

        let logs = try await fetchLogs(from: weekInterval.start, to: weekInterval.end)
        var dailyTotals: [DailyStats] = []
        for dayOffset in 0..<7 {
            guard let dayDate = calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayLogs = logs.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            dailyTotals.append(buildDailyStats(date: dayDate, logs: dayLogs))
        }

        let totalMinutes = dailyTotals.reduce(0) { $0 + $1.totalMinutes }

        // 前週の合計
        var previousWeekMinutes: Int?
        if let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekInterval.start) {
            let prevLogs = try await fetchLogs(from: prevWeekStart, to: weekInterval.start)
            previousWeekMinutes = prevLogs.reduce(0) { $0 + $1.durationMinutes }
        }

        return WeeklyStats(
            weekStart: weekInterval.start,
            dailyTotals: dailyTotals,
            totalMinutes: totalMinutes,
            previousWeekMinutes: previousWeekMinutes
        )
    }

    func fetchMonthlyStats(year: Int, month: Int) async throws -> [DailyStats] {
        let calendar = Calendar.current
        var components = DateComponents(year: year, month: month, day: 1)
        guard let monthStart = calendar.date(from: components) else { return [] }
        components.month = month + 1
        guard let monthEnd = calendar.date(from: components) else { return [] }

        let logs = try await fetchLogs(from: monthStart, to: monthEnd)
        let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var results: [DailyStats] = []
        for day in 1...daysInMonth {
            guard let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
            let dayStart = calendar.startOfDay(for: dayDate)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let dayLogs = logs.filter { $0.startedAt >= dayStart && $0.startedAt < dayEnd }
            results.append(buildDailyStats(date: dayDate, logs: dayLogs))
        }
        return results
    }

    func fetchCumulativeMinutes() async throws -> Int {
        struct SumResult: Codable {
            let totalMinutes: Int?
            enum CodingKeys: String, CodingKey {
                case totalMinutes = "duration_minutes"
            }
        }

        // RPC関数で集計。なければ全件取得
        let logs: [LogDTO] = try await client
            .from("logs")
            .select("duration_minutes")
            .execute()
            .value

        return logs.reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Private

    private func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO] {
        let formatter = ISO8601DateFormatter()
        let result: [LogDTO] = try await client
            .from("logs")
            .select()
            .gte("started_at", value: formatter.string(from: start))
            .lt("started_at", value: formatter.string(from: end))
            .order("started_at", ascending: true)
            .execute()
            .value
        return result
    }

    private func buildDailyStats(date: Date, logs: [LogDTO]) -> DailyStats {
        let totalMinutes = logs.reduce(0) { $0 + $1.durationMinutes }
        let grouped = Dictionary(grouping: logs, by: \.title)
        let breakdown = grouped.map { key, entries in
            CategoryBreakdownItem(
                name: key,
                minutes: entries.reduce(0) { $0 + $1.durationMinutes }
            )
        }.sorted { $0.minutes > $1.minutes }

        return DailyStats(date: date, totalMinutes: totalMinutes, categoryBreakdown: breakdown)
    }
}
