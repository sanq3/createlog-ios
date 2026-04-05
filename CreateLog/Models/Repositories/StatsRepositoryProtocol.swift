import Foundation

/// 統計情報
struct DailyStats: Sendable {
    let date: Date
    let totalMinutes: Int
    let categoryBreakdown: [CategoryBreakdownItem]
}

/// 週間統計
struct WeeklyStats: Sendable {
    let weekStart: Date
    let dailyTotals: [DailyStats]
    let totalMinutes: Int
    let previousWeekMinutes: Int?
}

/// レポート・統計データのアクセス
protocol StatsRepositoryProtocol: Sendable {
    /// 指定日の統計
    func fetchDailyStats(for date: Date) async throws -> DailyStats
    /// 指定週の統計
    func fetchWeeklyStats(containing date: Date) async throws -> WeeklyStats
    /// 指定月の日別統計 (カレンダーヒートマップ用)
    func fetchMonthlyStats(year: Int, month: Int) async throws -> [DailyStats]
    /// 累計時間
    func fetchCumulativeMinutes() async throws -> Int
}
