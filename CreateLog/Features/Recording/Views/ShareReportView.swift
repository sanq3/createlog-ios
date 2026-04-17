import SwiftUI
import Charts

struct ShareReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dependencies) private var dependencies
    @State private var selectedPeriod: SharePeriod = .week
    @State private var renderedImage: Image?
    @State private var currentHandle: String = ""
    /// 現在表示中の期間のカード内容。`loadCardContent` で期間別に埋める。
    @State private var cardContent: ShareCardContent = .empty(period: .week)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Period selector
                Picker("recording.duration", selection: $selectedPeriod) {
                    ForEach(SharePeriod.allCases) { period in
                        Text(period.label).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Card preview
                ScrollView {
                    shareCard
                        .padding(.horizontal, 32)
                        .padding(.bottom, 24)
                }
                .scrollIndicators(.hidden)

                Spacer()

                // Share button
                ShareLink(
                    item: renderedImage ?? Image(systemName: "square"),
                    preview: SharePreview(
                        "recording.report.title",
                        image: renderedImage ?? Image(systemName: "square")
                    )
                ) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                        Text("common.share")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.clAccent, in: .capsule)
                }
                .buttonStyle(.bounce)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.clBackground)
            .navigationTitle("recording.report.share")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                if let dto = try? await dependencies.profileRepository.fetchMyProfile() {
                    currentHandle = dto.handle ?? ""
                }
                await loadCardContent(period: selectedPeriod)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            }
            .onAppear { renderImage() }
            .onChange(of: selectedPeriod) { _, newValue in
                Task {
                    await loadCardContent(period: newValue)
                    renderImage()
                }
            }
        }
    }

    // MARK: - Share Card

    @ViewBuilder
    private var shareCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(cardContent.title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(cardContent.dateRange)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                // App logo watermark
                VStack(spacing: 2) {
                    Text("brand.wordmark.ja")
                        .font(.system(size: 11, weight: .heavy))
                    Text("CreateLog")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.clAccent, Color.clAccent.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Stats
            HStack(spacing: 0) {
                statColumn(value: cardContent.totalTime, label: "合計")
                statDivider
                statColumn(value: cardContent.dailyAvg, label: "日平均")
                statDivider
                statColumn(value: "\(cardContent.activeDays)日", label: "稼働日")
            }
            .padding(.vertical, 20)
            .background(Color(.systemBackground))

            // Category breakdown
            VStack(spacing: 12) {
                ForEach(cardContent.categories, id: \.name) { cat in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(cat.color)
                            .frame(width: 8, height: 8)

                        Text(cat.name)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(.label))

                        Spacer()

                        // Progress bar
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                Capsule()
                                    .fill(cat.color)
                                    .frame(width: proxy.size.width * cat.ratio)
                            }
                        }
                        .frame(width: 80, height: 6)

                        Text(DurationFormatter.formatHM(hours: cat.hours))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(.secondaryLabel))
                            .frame(width: 52, alignment: .trailing)
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground))

            // Footer
            HStack {
                Text("@\(currentHandle.isEmpty ? "createlog" : currentHandle)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
                Spacer()
                Text("createlog.app")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 20, y: 8)
    }

    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(.label))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 0.5, height: 36)
    }

    // MARK: - Render

    private func renderImage() {
        let renderer = ImageRenderer(content: shareCard.frame(width: 340))
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }

    // MARK: - Data Loading

    /// 指定期間のシェアカード内容を実 stats repository から構築する。
    /// - week: `fetchWeeklyStats(containing:)` → 7 日集計 + 今週のカテゴリ
    /// - month: `fetchMonthlyStats(year:month:)` → 月の日別集計 → 合算
    /// - total: `fetchCumulativeMinutes()` + 直近月のカテゴリ内訳 (全期間 API がないため代替)
    private func loadCardContent(period: SharePeriod) async {
        let now = Date()
        let calendar = Calendar.current
        switch period {
        case .week:
            guard let weekly = try? await dependencies.statsRepository.fetchWeeklyStats(containing: now) else {
                cardContent = .empty(period: period)
                return
            }
            cardContent = Self.makeWeekly(weekly: weekly, now: now, calendar: calendar)

        case .month:
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            guard let monthly = try? await dependencies.statsRepository.fetchMonthlyStats(year: year, month: month) else {
                cardContent = .empty(period: period)
                return
            }
            cardContent = Self.makeMonthly(monthly: monthly, year: year, month: month)

        case .total:
            async let cumulativeFetch = (try? await dependencies.statsRepository.fetchCumulativeMinutes()) ?? 0
            // 累計集計 API は無いため、直近月の stats を基にカテゴリ内訳を出す。
            let year = calendar.component(.year, from: now)
            let month = calendar.component(.month, from: now)
            async let monthlyFetch = (try? await dependencies.statsRepository.fetchMonthlyStats(year: year, month: month)) ?? []
            let (cumulative, monthly) = await (cumulativeFetch, monthlyFetch)
            cardContent = Self.makeTotal(cumulativeMinutes: cumulative, recentMonthly: monthly)
        }
    }

    // MARK: - Share Card Builders

    private static func makeWeekly(weekly: WeeklyStats, now: Date, calendar: Calendar) -> ShareCardContent {
        let sorted = weekly.dailyTotals.sorted { $0.date < $1.date }
        let activeDays = sorted.filter { $0.totalMinutes > 0 }.count
        let totalHours = Double(weekly.totalMinutes) / 60.0
        let avg = activeDays > 0 ? totalHours / Double(activeDays) : 0
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月d日"
        let startDate = sorted.first?.date ?? weekly.weekStart
        let endDate = sorted.last?.date ?? calendar.date(byAdding: .day, value: 6, to: startDate) ?? startDate
        let range = "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"

        let categories = aggregateCategories(from: sorted)

        return ShareCardContent(
            title: "週間レポート",
            dateRange: range,
            totalTime: DurationFormatter.formatHM(hours: totalHours),
            dailyAvg: DurationFormatter.formatHM(hours: avg),
            activeDays: activeDays,
            categories: categories
        )
    }

    private static func makeMonthly(monthly: [DailyStats], year: Int, month: Int) -> ShareCardContent {
        let totalMinutes = monthly.reduce(0) { $0 + $1.totalMinutes }
        let totalHours = Double(totalMinutes) / 60.0
        let activeDays = monthly.filter { $0.totalMinutes > 0 }.count
        let avg = activeDays > 0 ? totalHours / Double(activeDays) : 0

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年M月"
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        let range = formatter.string(from: Calendar.current.date(from: comps) ?? Date())

        let categories = aggregateCategories(from: monthly)

        return ShareCardContent(
            title: "月間レポート",
            dateRange: range,
            totalTime: DurationFormatter.formatHM(hours: totalHours),
            dailyAvg: DurationFormatter.formatHM(hours: avg),
            activeDays: activeDays,
            categories: categories
        )
    }

    private static func makeTotal(cumulativeMinutes: Int, recentMonthly: [DailyStats]) -> ShareCardContent {
        let totalHours = Double(cumulativeMinutes) / 60.0
        let activeDays = recentMonthly.filter { $0.totalMinutes > 0 }.count
        // cumulative の「全期間の稼働日」は取れないので 0 は非表示的に扱う。
        // カテゴリ内訳は直近月ベース (全期間集計 API なし)。
        let categories = aggregateCategories(from: recentMonthly)
        let avg: Double = activeDays > 0 ? (Double(recentMonthly.reduce(0) { $0 + $1.totalMinutes }) / 60.0 / Double(activeDays)) : 0

        return ShareCardContent(
            title: "累計レポート",
            dateRange: "全期間",
            totalTime: DurationFormatter.formatHM(hours: totalHours),
            dailyAvg: DurationFormatter.formatHM(hours: avg),
            activeDays: activeDays,
            categories: categories
        )
    }

    /// DailyStats 配列から上位カテゴリを集計し `CategoryStat` に変換 (最大 5 件)。
    private static func aggregateCategories(from stats: [DailyStats]) -> [ShareCardContent.CategoryStat] {
        var minutesByCategory: [String: Int] = [:]
        for day in stats {
            for breakdown in day.categoryBreakdown {
                minutesByCategory[breakdown.name, default: 0] += breakdown.minutes
            }
        }
        let sorted = minutesByCategory
            .sorted { $0.value > $1.value }
            .prefix(5)
        guard let maxMinutes = sorted.first?.value, maxMinutes > 0 else { return [] }
        return sorted.map { name, minutes in
            let hours = Double(minutes) / 60.0
            let ratio = CGFloat(minutes) / CGFloat(maxMinutes)
            return ShareCardContent.CategoryStat(
                name: name,
                hours: hours,
                ratio: ratio,
                color: LogEntry.color(for: name)
            )
        }
    }
}

// MARK: - Models

enum SharePeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case total

    var id: String { rawValue }

    var label: String {
        switch self {
        case .week: "recording.thisWeek"
        case .month: "recording.thisMonth"
        case .total: "recording.total"
        }
    }
}

private struct ShareCardContent {
    let title: String
    let dateRange: String
    let totalTime: String
    let dailyAvg: String
    let activeDays: Int
    let categories: [CategoryStat]

    struct CategoryStat {
        let name: String
        let hours: Double
        let ratio: CGFloat
        let color: Color
    }

    /// データ未取得時のプレースホルダ (0 値)。カードのレイアウトを崩さず表示する。
    static func empty(period: SharePeriod) -> ShareCardContent {
        let title: String
        switch period {
        case .week: title = "週間レポート"
        case .month: title = "月間レポート"
        case .total: title = "累計レポート"
        }
        return ShareCardContent(
            title: title,
            dateRange: "",
            totalTime: DurationFormatter.formatHM(hours: 0),
            dailyAvg: DurationFormatter.formatHM(hours: 0),
            activeDays: 0,
            categories: []
        )
    }
}
