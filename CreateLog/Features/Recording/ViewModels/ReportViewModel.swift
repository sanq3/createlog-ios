import SwiftUI
import SwiftData

/// レポート画面のViewModel
@MainActor @Observable
final class ReportViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let statsRepository: (any StatsRepositoryProtocol)?

    // MARK: - State

    enum Period: Int, CaseIterable {
        case today = 0, week, month, total

        var label: String {
            switch self {
            case .today: "recording.today"
            case .week: "recording.thisWeek"
            case .month: "recording.thisMonth"
            case .total: "recording.total"
            }
        }
    }

    var selectedPeriod: Period = .week
    var totalMinutes: Int = 0
    var dailyAverage: Int = 0
    var weekOverWeekChange: Double?
    var categoryBreakdown: [CategoryBreakdownItem] = []
    var weeklyTotals: [(day: String, minutes: Int)] = []
    var isLoading = false

    // MARK: - Init

    init(
        modelContext: ModelContext,
        statsRepository: (any StatsRepositoryProtocol)? = nil
    ) {
        self.modelContext = modelContext
        self.statsRepository = statsRepository
    }

    // MARK: - Data Loading

    func loadReport() {
        loadLocalData()
        Task { await syncRemote() }
    }

    func onPeriodChange() {
        loadLocalData()
        Task { await syncRemote() }
    }

    private func loadLocalData() {
        do {
            let descriptor = FetchDescriptor<SDTimeEntry>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
            let allEntries = try modelContext.fetch(descriptor)

            let calendar = Calendar.current
            let now = Date()

            let filtered: [SDTimeEntry]
            switch selectedPeriod {
            case .today:
                filtered = allEntries.filter { calendar.isDateInToday($0.startDate) }
            case .week:
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                filtered = allEntries.filter { $0.startDate >= weekStart }
            case .month:
                let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
                filtered = allEntries.filter { $0.startDate >= monthStart }
            case .total:
                filtered = allEntries
            }

            totalMinutes = filtered.reduce(0) { $0 + $1.durationMinutes }

            // カテゴリ内訳
            let grouped = Dictionary(grouping: filtered, by: \.categoryName)
            categoryBreakdown = grouped.map {
                CategoryBreakdownItem(name: $0.key, minutes: $0.value.reduce(0) { $0 + $1.durationMinutes })
            }.sorted { $0.minutes > $1.minutes }

            // 週間日別
            if selectedPeriod == .week || selectedPeriod == .today {
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
                let dayLabels = ["weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat", "weekday.sun"]
                weeklyTotals = (0..<7).map { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart) ?? now
                    let dayEntries = allEntries.filter { calendar.isDate($0.startDate, inSameDayAs: day) }
                    let mins = dayEntries.reduce(0) { $0 + $1.durationMinutes }
                    return (dayLabels[offset], mins)
                }
            }

            // 日平均
            let activeDays = Set(filtered.map { calendar.startOfDay(for: $0.startDate) }).count
            dailyAverage = activeDays > 0 ? totalMinutes / activeDays : 0

            // 前週比
            weekOverWeekChange = RecordingViewModel.computeWeekOverWeekChange(from: allEntries)

        } catch {
            totalMinutes = 0
            categoryBreakdown = []
        }
    }

    private func syncRemote() async {
        guard let repo = statsRepository else { return }
        do {
            let weeklyStats = try await repo.fetchWeeklyStats(containing: Date())
            // リモートデータがあればローカルを更新
            if weeklyStats.totalMinutes > 0 {
                let dayLabels = ["weekday.mon", "weekday.tue", "weekday.wed", "weekday.thu", "weekday.fri", "weekday.sat", "weekday.sun"]
                weeklyTotals = weeklyStats.dailyTotals.enumerated().map { index, stats in
                    let label = index < dayLabels.count ? dayLabels[index] : "\(index)"
                    return (label, stats.totalMinutes)
                }
            }
        } catch {
            // リモート同期失敗はサイレント
        }
    }

}
