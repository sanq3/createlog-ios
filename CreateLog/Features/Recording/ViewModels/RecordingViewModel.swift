import SwiftUI
import SwiftData

@MainActor @Observable
final class RecordingViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let modelContext: ModelContext

    // MARK: - State

    var todayTotalMinutes: Int = 0
    var cumulativeTotalMinutes: Int = 0
    var weekOverWeekChange: Double? = nil // e.g. +0.15 = 15%増, -0.3 = 30%減
    var categoryBreakdown: [CategoryBreakdownItem] = []
    var tags: [SDProject] = []
    var recentEntries: [SDTimeEntry] = []

    // Time input
    var showTimeInput: Bool = false
    var selectedTag: SDProject?
    var timeInputText: String = ""

    // Wizard
    var showCreateTag: Bool = false
    var wizardStep: Int = 0
    var selectedGenre: String = ""
    var selectedActivity: String = ""
    var projectName: String = ""

    // Timer
    var timerTag: SDProject?
    var timerStartDate: Date?
    var timerElapsed: TimeInterval = 0
    @ObservationIgnored private var timerTask: Task<Void, Never>?

    // Picker input
    var pickerHours: Int = 0
    var pickerMinutes: Int = 0

    // MARK: - Constants

    static let genres: [(name: String, activities: [String])] = [
        ("プログラミング", ["iOS開発", "Android開発", "Web開発", "バックエンド", "インフラ", "バグ修正"]),
        ("デザイン", ["UIデザイン", "UXデザイン", "グラフィック", "ロゴ制作"]),
        ("学習", ["プログラミング学習", "語学", "読書", "資格勉強"]),
        ("クリエイティブ", ["動画制作", "音楽制作", "ライティング", "ブログ"]),
        ("ビジネス", ["マーケティング", "営業", "企画", "事務", "経理"]),
        ("コミュニケーション", ["ミーティング", "1on1", "レビュー", "メール対応"]),
    ]

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Data Loading

    func loadData() {
        loadTags()
        loadEntries()
    }

    private func loadTags() {
        let descriptor = FetchDescriptor<SDProject>(sortBy: [SortDescriptor(\.createdAt)])
        tags = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadEntries() {
        let descriptor = FetchDescriptor<SDTimeEntry>(sortBy: [SortDescriptor(\.startDate, order: .reverse)])
        let allEntries = (try? modelContext.fetch(descriptor)) ?? []

        recentEntries = Array(allEntries.prefix(7))

        let todayEntries = allEntries.filter { Self.isToday($0.startDate) }
        todayTotalMinutes = Self.computeTodayTotal(from: todayEntries)
        categoryBreakdown = Self.computeCategoryBreakdown(from: todayEntries)
        cumulativeTotalMinutes = allEntries.reduce(0) { $0 + $1.durationMinutes }
        let computed = Self.computeWeekOverWeekChange(from: allEntries)
        weekOverWeekChange = computed ?? 0.15 // Mock: +15% when no real data
    }

    // MARK: - Actions

    func selectTag(_ tag: SDProject) {
        selectedTag = tag
        HapticManager.selection()
    }

    var isTimerRunning: Bool { timerTag != nil }

    func startTimer(for tag: SDProject) {
        timerTag = tag
        timerStartDate = Date()
        timerElapsed = 0
        HapticManager.medium()

        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, let start = self.timerStartDate else { break }
                self.timerElapsed = Date().timeIntervalSince(start)
            }
        }
    }

    func stopTimer() {
        guard let tag = timerTag, let start = timerStartDate else { return }
        timerTask?.cancel()
        timerTask = nil

        let minutes = max(1, Int(Date().timeIntervalSince(start) / 60))
        let entry = SDTimeEntry(
            startDate: start,
            endDate: Date(),
            durationMinutes: minutes,
            projectName: tag.name,
            categoryName: tag.category?.name ?? "その他"
        )
        modelContext.insert(entry)

        timerTag = nil
        timerStartDate = nil
        timerElapsed = 0
        HapticManager.success()
        loadEntries()
    }

    func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerTag = nil
        timerStartDate = nil
        timerElapsed = 0
        HapticManager.light()
    }

    var timerFormatted: String {
        let total = Int(timerElapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }

    func saveTimeEntry() {
        guard let tag = selectedTag else { return }
        let minutes = Self.parseDuration(from: timeInputText)
        guard minutes > 0 else { return }

        let entry = SDTimeEntry(
            startDate: Date().addingTimeInterval(-Double(minutes * 60)),
            endDate: Date(),
            durationMinutes: minutes,
            projectName: tag.name,
            categoryName: tag.category?.name ?? "その他"
        )
        modelContext.insert(entry)

        showTimeInput = false
        timeInputText = ""
        HapticManager.success()
        loadEntries()
    }

    func savePresetTime(minutes: Int) {
        guard let tag = selectedTag else { return }

        let entry = SDTimeEntry(
            startDate: Date().addingTimeInterval(-Double(minutes * 60)),
            endDate: Date(),
            durationMinutes: minutes,
            projectName: tag.name,
            categoryName: tag.category?.name ?? "その他"
        )
        modelContext.insert(entry)

        showTimeInput = false
        timeInputText = ""
        HapticManager.success()
        loadEntries()
    }

    func savePickerTime() {
        let minutes = pickerHours * 60 + pickerMinutes
        guard minutes > 0 else { return }

        let projectName = selectedTag?.name ?? "その他"
        let categoryName = selectedTag?.category?.name ?? "その他"

        let entry = SDTimeEntry(
            startDate: Date().addingTimeInterval(-Double(minutes * 60)),
            endDate: Date(),
            durationMinutes: minutes,
            projectName: projectName,
            categoryName: categoryName
        )
        modelContext.insert(entry)

        showTimeInput = false
        timeInputText = ""
        HapticManager.success()
        loadEntries()
    }

    // MARK: - Wizard Actions

    func selectGenre(_ genre: String) {
        selectedGenre = genre
        wizardStep = 1
        HapticManager.light()
    }

    func selectActivity(_ activity: String) {
        selectedActivity = activity
        wizardStep = 2
        HapticManager.light()
    }

    func saveTag(withProjectName name: String?) {
        let tagName: String
        if let name, !name.isEmpty {
            tagName = "\(selectedActivity) / \(name)"
        } else {
            tagName = selectedActivity
        }

        let categoryName = Self.detectCategory(selectedGenre, activity: selectedActivity)
        let descriptor = FetchDescriptor<SDCategory>(predicate: #Predicate { cat in
            cat.name == categoryName
        })
        let category = (try? modelContext.fetch(descriptor))?.first

        let tag = SDProject(name: tagName, category: category)
        modelContext.insert(tag)

        showCreateTag = false
        HapticManager.success()
        loadTags()
    }

    func resetWizard() {
        wizardStep = 0
        selectedGenre = ""
        selectedActivity = ""
        projectName = ""
    }

    /// 既存タグから重複なしのプロジェクト名候補を返す
    var existingProjectNames: [String] {
        let names = tags.compactMap { tag -> String? in
            guard tag.name.contains(" / ") else { return nil }
            return String(tag.name.split(separator: " / ", maxSplits: 1).last ?? "")
        }
        return Array(Set(names)).sorted()
    }

    func startCreateTag() {
        resetWizard()
        showCreateTag = true
        HapticManager.light()
    }

    func goBackWizard() {
        if wizardStep > 0 {
            wizardStep -= 1
        }
    }

    // MARK: - Pure Functions (nonisolated, Testable)

    nonisolated static func parseDuration(from text: String) -> Int {
        var total = 0

        if let match = text.range(of: "(\\d+)時間", options: .regularExpression) {
            total += (Int(text[match].replacingOccurrences(of: "時間", with: "")) ?? 0) * 60
        }
        if let match = text.range(of: "(\\d+)h", options: [.regularExpression, .caseInsensitive]) {
            total += (Int(text[match].replacingOccurrences(of: "h", with: "").replacingOccurrences(of: "H", with: "")) ?? 0) * 60
        }
        if let match = text.range(of: "(\\d+)分", options: .regularExpression) {
            total += Int(text[match].replacingOccurrences(of: "分", with: "")) ?? 0
        }
        if let match = text.range(of: "(\\d+)m", options: [.regularExpression, .caseInsensitive]) {
            total += Int(text[match].replacingOccurrences(of: "m", with: "").replacingOccurrences(of: "M", with: "")) ?? 0
        }

        if total == 0, let num = Int(text.trimmingCharacters(in: .whitespaces)), num > 0 {
            total = num * 60
        }

        return total
    }

    nonisolated static func formatDuration(_ minutes: Int) -> String {
        DurationFormatter.format(minutes: minutes)
    }

    nonisolated static func detectCategory(_ genre: String, activity: String) -> String {
        switch genre {
        case "プログラミング": return "開発"
        case "デザイン": return "デザイン"
        case "学習": return "学習"
        case "クリエイティブ": return "ライティング"
        case "ビジネス": return "マーケティング"
        case "コミュニケーション": return "ミーティング"
        default: return "その他"
        }
    }

    nonisolated static func computeTodayTotal(from entries: [SDTimeEntry]) -> Int {
        entries
            .filter { isToday($0.startDate) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    nonisolated static func computeCategoryBreakdown(from entries: [SDTimeEntry]) -> [CategoryBreakdownItem] {
        let todayEntries = entries.filter { isToday($0.startDate) }
        let grouped = Dictionary(grouping: todayEntries, by: \.categoryName)
        return grouped
            .map { CategoryBreakdownItem(name: $0.key, minutes: $0.value.reduce(0) { $0 + $1.durationMinutes }) }
            .sorted { $0.minutes > $1.minutes }
    }

    static func colorForTag(_ tag: SDProject) -> Color {
        if let cat = tag.category {
            return Color(cat.colorName)
        }
        return Color("clCat07")
    }

    nonisolated static func computeWeekOverWeekChange(from entries: [SDTimeEntry]) -> Double? {
        let cal = Calendar.current
        let now = Date()

        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return nil }
        guard let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) else { return nil }

        let thisWeek = entries
            .filter { $0.startDate >= thisWeekStart }
            .reduce(0) { $0 + $1.durationMinutes }

        let lastWeek = entries
            .filter { $0.startDate >= lastWeekStart && $0.startDate < thisWeekStart }
            .reduce(0) { $0 + $1.durationMinutes }

        guard lastWeek > 0 else { return nil }
        return Double(thisWeek - lastWeek) / Double(lastWeek)
    }

    nonisolated private static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}

// MARK: - Supporting Types

struct CategoryBreakdownItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let minutes: Int
}
