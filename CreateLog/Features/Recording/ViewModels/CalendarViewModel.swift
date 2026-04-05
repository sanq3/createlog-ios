import SwiftUI
import SwiftData

/// カレンダー画面のViewModel
@MainActor @Observable
final class CalendarViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let statsRepository: (any StatsRepositoryProtocol)?

    // MARK: - State

    var displayYear: Int
    var displayMonth: Int
    var dayHours: [Int: Double] = [:]
    var monthTotalMinutes: Int = 0
    var topCategory: String = ""
    var bestDay: Int = 0

    var selectedDay: Int?
    var selectedDayEntries: [SDTimeEntry] = []

    // MARK: - Computed

    var monthTitle: String {
        "\(displayYear)年\(displayMonth)月"
    }

    var daysInMonth: Int {
        let calendar = Calendar.current
        let components = DateComponents(year: displayYear, month: displayMonth)
        guard let date = calendar.date(from: components) else { return 30 }
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    var firstDayOffset: Int {
        let calendar = Calendar.current
        let components = DateComponents(year: displayYear, month: displayMonth, day: 1)
        guard let date = calendar.date(from: components) else { return 0 }
        // 月曜始まり (2=月 → 0, 3=火 → 1, ... 1=日 → 6)
        let weekday = calendar.component(.weekday, from: date)
        return (weekday + 5) % 7
    }

    // MARK: - Init

    init(
        modelContext: ModelContext,
        statsRepository: (any StatsRepositoryProtocol)? = nil
    ) {
        self.modelContext = modelContext
        self.statsRepository = statsRepository

        let calendar = Calendar.current
        let now = Date()
        displayYear = calendar.component(.year, from: now)
        displayMonth = calendar.component(.month, from: now)
    }

    // MARK: - Actions

    func loadMonth() {
        loadLocalData()
        Task { await syncRemote() }
    }

    func goToPreviousMonth() {
        if displayMonth == 1 {
            displayMonth = 12
            displayYear -= 1
        } else {
            displayMonth -= 1
        }
        selectedDay = nil
        loadMonth()
    }

    func goToNextMonth() {
        if displayMonth == 12 {
            displayMonth = 1
            displayYear += 1
        } else {
            displayMonth += 1
        }
        selectedDay = nil
        loadMonth()
    }

    func selectDay(_ day: Int) {
        selectedDay = day
        loadDayEntries(day)
    }

    // MARK: - Data Loading

    private func loadLocalData() {
        do {
            let calendar = Calendar.current
            let startComponents = DateComponents(year: displayYear, month: displayMonth, day: 1)
            guard let monthStart = calendar.date(from: startComponents) else { return }
            let endComponents = DateComponents(year: displayYear, month: displayMonth + 1, day: 1)
            guard let monthEnd = calendar.date(from: endComponents) else { return }

            let descriptor = FetchDescriptor<SDTimeEntry>(
                predicate: #Predicate<SDTimeEntry> { entry in
                    entry.startDate >= monthStart && entry.startDate < monthEnd
                },
                sortBy: [SortDescriptor(\.startDate)]
            )
            let entries = try modelContext.fetch(descriptor)

            // 日別集計
            var hours: [Int: Double] = [:]
            var categoryMinutes: [String: Int] = [:]
            var bestDayMinutes = 0

            for entry in entries {
                let day = calendar.component(.day, from: entry.startDate)
                hours[day, default: 0] += Double(entry.durationMinutes) / 60.0
                categoryMinutes[entry.categoryName, default: 0] += entry.durationMinutes

                let dayTotal = Int(hours[day, default: 0] * 60)
                if dayTotal > bestDayMinutes {
                    bestDayMinutes = dayTotal
                    bestDay = day
                }
            }

            dayHours = hours
            monthTotalMinutes = entries.reduce(0) { $0 + $1.durationMinutes }
            topCategory = categoryMinutes.max(by: { $0.value < $1.value })?.key ?? ""
        } catch {
            dayHours = [:]
            monthTotalMinutes = 0
        }
    }

    private func loadDayEntries(_ day: Int) {
        let calendar = Calendar.current
        guard let dayDate = calendar.date(from: DateComponents(year: displayYear, month: displayMonth, day: day)) else {
            selectedDayEntries = []
            return
        }
        let dayStart = calendar.startOfDay(for: dayDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            selectedDayEntries = []
            return
        }

        do {
            let descriptor = FetchDescriptor<SDTimeEntry>(
                predicate: #Predicate<SDTimeEntry> { entry in
                    entry.startDate >= dayStart && entry.startDate < dayEnd
                },
                sortBy: [SortDescriptor(\.startDate)]
            )
            selectedDayEntries = try modelContext.fetch(descriptor)
        } catch {
            selectedDayEntries = []
        }
    }

    private func syncRemote() async {
        guard let repo = statsRepository else { return }
        do {
            let remoteStats = try await repo.fetchMonthlyStats(year: displayYear, month: displayMonth)
            if !remoteStats.isEmpty {
                var hours: [Int: Double] = [:]
                let calendar = Calendar.current
                for stats in remoteStats {
                    let day = calendar.component(.day, from: stats.date)
                    hours[day] = Double(stats.totalMinutes) / 60.0
                }
                if hours.values.reduce(0, +) > 0 {
                    dayHours = hours
                }
            }
        } catch {
            // サイレント
        }
    }
}
