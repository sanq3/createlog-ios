import Foundation
import Testing
@testable import CreateLog

@Suite("RecordingViewModel")
struct RecordingViewModelTests {

    // MARK: - parseDuration

    @Test("parseDuration: 時間表記", arguments: [
        ("3時間", 180),
        ("1時間", 60),
        ("0時間", 0),
    ])
    func parseDurationHours(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    @Test("parseDuration: h/m表記", arguments: [
        ("1h30m", 90),
        ("2h", 120),
        ("30m", 30),
        ("1h45m", 105),
    ])
    func parseDurationHM(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    @Test("parseDuration: 分表記", arguments: [
        ("45分", 45),
        ("90分", 90),
        ("15分", 15),
    ])
    func parseDurationMinutes(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    @Test("parseDuration: 複合表記", arguments: [
        ("2時間30分", 150),
        ("1時間15分", 75),
    ])
    func parseDurationCombined(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    @Test("parseDuration: 数字のみは時間扱い", arguments: [
        ("2", 120),
        ("3", 180),
        ("1", 60),
    ])
    func parseDurationBareNumber(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    @Test("parseDuration: 無効な入力", arguments: [
        ("", 0),
        ("abc", 0),
        ("   ", 0),
    ])
    func parseDurationInvalid(input: String, expected: Int) {
        #expect(RecordingViewModel.parseDuration(from: input) == expected)
    }

    // MARK: - formatDuration

    @Test("formatDuration", arguments: [
        (90, "1h 30m"),
        (120, "2h"),
        (30, "30m"),
        (0, "0分"),
        (61, "1時間1分"),
        (360, "6時間"),
    ])
    func formatDuration(minutes: Int, expected: String) {
        #expect(RecordingViewModel.formatDuration(minutes) == expected)
    }

    // MARK: - detectCategory

    @Test("detectCategory: ジャンル→カテゴリ変換", arguments: [
        ("プログラミング", "iOS開発", "開発"),
        ("デザイン", "UIデザイン", "デザイン"),
        ("学習", "読書", "学習"),
        ("クリエイティブ", "ブログ", "ライティング"),
        ("ビジネス", "営業", "マーケティング"),
        ("コミュニケーション", "ミーティング", "ミーティング"),
        ("不明なジャンル", "なにか", "その他"),
    ])
    func detectCategory(genre: String, activity: String, expected: String) {
        #expect(RecordingViewModel.detectCategory(genre, activity: activity) == expected)
    }

    // MARK: - computeTodayTotal

    @Test("computeTodayTotal: 今日のエントリのみ合計")
    func todayTotal() {
        let now = Self.fixedNoon
        let today1 = makeEntry(minutesAgo: 60, duration: 30, project: "A", category: "開発", now: now)
        let today2 = makeEntry(minutesAgo: 120, duration: 45, project: "B", category: "学習", now: now)
        let yesterday = makeEntry(daysAgo: 1, duration: 90, project: "C", category: "開発", now: now)

        let total = RecordingViewModel.computeTodayTotal(from: [today1, today2, yesterday], now: now)
        #expect(total == 75) // 30 + 45
    }

    @Test("computeTodayTotal: エントリなしなら0")
    func todayTotalEmpty() {
        #expect(RecordingViewModel.computeTodayTotal(from: []) == 0)
    }

    // MARK: - computeCategoryBreakdown

    @Test("computeCategoryBreakdown: カテゴリ別集計")
    func categoryBreakdown() {
        let now = Self.fixedNoon
        let entries = [
            makeEntry(minutesAgo: 60, duration: 60, project: "A", category: "開発", now: now),
            makeEntry(minutesAgo: 180, duration: 30, project: "B", category: "開発", now: now),
            makeEntry(minutesAgo: 300, duration: 45, project: "C", category: "学習", now: now),
        ]

        let breakdown = RecordingViewModel.computeCategoryBreakdown(from: entries, now: now)

        #expect(breakdown.count == 2)
        #expect(breakdown[0].name == "開発") // 90分が最大
        #expect(breakdown[0].minutes == 90)
        #expect(breakdown[1].name == "学習")
        #expect(breakdown[1].minutes == 45)
    }

    @Test("computeCategoryBreakdown: 空なら空配列")
    func categoryBreakdownEmpty() {
        let breakdown = RecordingViewModel.computeCategoryBreakdown(from: [])
        #expect(breakdown.isEmpty)
    }

    // MARK: - Helpers

    /// 日付境界からの距離を十分に確保した固定時刻 (今日の 12:00)。
    /// 時間依存テストが深夜帯の実行で偽陽性 crash を起こさないように使う。
    private static let fixedNoon: Date = {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 12
        comps.minute = 0
        comps.second = 0
        return Calendar.current.date(from: comps) ?? Date()
    }()

    private func makeEntry(minutesAgo: Int = 60, duration: Int, project: String, category: String, now: Date = Date()) -> SDTimeEntry {
        let end = now
        let start = end.addingTimeInterval(-Double(minutesAgo * 60))
        return SDTimeEntry(
            startDate: start,
            endDate: end,
            durationMinutes: duration,
            projectName: project,
            categoryName: category
        )
    }

    private func makeEntry(daysAgo: Int, duration: Int, project: String, category: String, now: Date = Date()) -> SDTimeEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        return SDTimeEntry(
            startDate: date,
            endDate: date.addingTimeInterval(Double(duration * 60)),
            durationMinutes: duration,
            projectName: project,
            categoryName: category
        )
    }
}
