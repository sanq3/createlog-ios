import SwiftUI
import Charts

struct ReportDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @State private var animateIn = false
    @State private var showShare = false
    @State private var weeklyStackedData: [WeeklyStackedEntry] = []
    @State private var weeklyHoursData: [(day: String, hours: Double)] = []

    /// 今日 / 今週 / 今月の合計時間 (時間単位)。statsRepository から取得。
    @State private var todayHours: Double = 0
    @State private var weekHours: Double = 0
    @State private var monthHours: Double = 0

    /// 今月のカテゴリ別集計。donut chart 用。
    @State private var monthCategories: [(name: String, hours: Double)] = []

    /// 週送りオフセット。0 = 今週、-1 = 先週、+1 = 来週。
    @State private var weekOffset: Int = 0

    private var totalCategoryHours: Double {
        monthCategories.reduce(0) { $0 + $1.hours }
    }

    /// 現在表示中の週の開始日 (月曜)
    private var currentWeekStart: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start else {
            return Date()
        }
        return calendar.date(byAdding: .day, value: weekOffset * 7, to: weekStart) ?? weekStart
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        let start = currentWeekStart
        guard let end = calendar.date(byAdding: .day, value: 6, to: start) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }

    private var weekAverageText: String {
        let total = weeklyHoursData.reduce(0) { $0 + $1.hours }
        let avgHours = total / 7
        let hours = Int(avgHours)
        let minutes = Int((avgHours - Double(hours)) * 60)
        return "avg \(hours)h \(minutes)m"
    }

    private let donutRadius: CGFloat = 60
    private let donutStroke: CGFloat = 24

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                kpiRow
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 20)

                HStack {
                    Text("recording.thisMonth.category")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.clTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

                donutSection
                    .padding(.bottom, 20)

                Rectangle()
                    .fill(Color.clBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)

                HStack {
                    Text("recording.weeklyTrend.long")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.clTextTertiary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 6)

                weeklySection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("recording.report")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.medium()
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .light))
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareReportView()
        }
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.1).delay(0.1)) {
                animateIn = true
            }
        }
        .task {
            await loadAllData()
        }
        .refreshable {
            await loadAllData()
        }
        .onChange(of: weekOffset) { _, _ in
            Task { await loadWeeklyData() }
        }
    }

    /// 画面表示用の全データを並列取得する。
    /// - KPI 3 値 (today/week/month)
    /// - 月カテゴリ内訳 (donut)
    /// - 週別カテゴリ (stacked bar + daily hours)
    private func loadAllData() async {
        async let today = loadDailyMinutes(for: Date())
        async let month = loadMonthlyData(for: Date())
        async let week = loadWeeklyDataAsync()

        todayHours = await today
        let (monthTotal, categories) = await month
        monthHours = monthTotal
        monthCategories = categories
        let (weekTotal, hoursData, stacked) = await week
        weekHours = weekTotal
        weeklyHoursData = hoursData
        weeklyStackedData = stacked
    }

    private func loadWeeklyData() async {
        let (weekTotal, hoursData, stacked) = await loadWeeklyDataAsync()
        weekHours = weekTotal
        weeklyHoursData = hoursData
        weeklyStackedData = stacked
    }

    private func loadDailyMinutes(for date: Date) async -> Double {
        guard let daily = try? await dependencies.statsRepository.fetchDailyStats(for: date) else { return 0 }
        return Double(daily.totalMinutes) / 60.0
    }

    /// 今月の合計時間 + カテゴリ別内訳を集計する
    private func loadMonthlyData(for date: Date) async -> (total: Double, categories: [(name: String, hours: Double)]) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        guard let stats = try? await dependencies.statsRepository.fetchMonthlyStats(year: year, month: month) else {
            return (0, [])
        }
        let totalMinutes = stats.reduce(0) { $0 + $1.totalMinutes }
        var categoryMinutes: [String: Int] = [:]
        for day in stats {
            for breakdown in day.categoryBreakdown {
                categoryMinutes[breakdown.name, default: 0] += breakdown.minutes
            }
        }
        let sorted = categoryMinutes
            .sorted { $0.value > $1.value }
            .map { (name: $0.key, hours: Double($0.value) / 60.0) }
        return (Double(totalMinutes) / 60.0, sorted)
    }

    /// 表示中の週 (weekOffset 適用) の合計 / 曜日別 / stacked を取得する
    private func loadWeeklyDataAsync() async -> (total: Double, hours: [(day: String, hours: Double)], stacked: [WeeklyStackedEntry]) {
        guard let weekly = try? await dependencies.statsRepository.fetchWeeklyStats(containing: currentWeekStart) else {
            return (0, [], [])
        }
        let labels = ["月", "火", "水", "木", "金", "土", "日"]
        let sorted = weekly.dailyTotals.sorted { $0.date < $1.date }

        var hoursData: [(day: String, hours: Double)] = []
        var stacked: [WeeklyStackedEntry] = []
        for (idx, stats) in sorted.enumerated() {
            let label = idx < labels.count ? labels[idx] : ""
            hoursData.append((day: label, hours: Double(stats.totalMinutes) / 60.0))
            for breakdown in stats.categoryBreakdown {
                stacked.append(WeeklyStackedEntry(
                    day: label,
                    category: breakdown.name,
                    hours: Double(breakdown.minutes) / 60.0
                ))
            }
        }
        return (Double(weekly.totalMinutes) / 60.0, hoursData, stacked)
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiItem(hours: animateIn ? todayHours : 0, label: "recording.today")
            kpiItem(hours: animateIn ? weekHours : 0, label: "recording.thisWeek")
            kpiItem(hours: animateIn ? monthHours : 0, label: "recording.thisMonth")
        }
    }

    private func kpiItem(hours: Double, label: String) -> some View {
        let minutes = Int(hours * 60)
        let h = minutes / 60
        let m = minutes % 60
        return VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if h > 0 {
                    Text("\(h)")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.clTextPrimary)
                    Text("h")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.clTextTertiary)
                }
                Text("\(h > 0 ? String(format: "%02d", m) : "\(m)")")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                Text("m")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Donut Section

    private var donutSection: some View {
        VStack(spacing: 14) {
            GeometryReader { proxy in
                let size = proxy.size
                let center = CGPoint(x: size.width / 2, y: size.height / 2)

                ZStack {
                    donutChart
                        .frame(width: donutRadius * 2, height: donutRadius * 2)
                        .position(center)

                    ForEach(0..<min(3, monthCategories.count), id: \.self) { index in
                        calloutView(index: index, center: center)
                    }
                    .opacity(animateIn ? 1 : 0)
                }
            }
            .frame(height: 220)

            HStack(spacing: 16) {
                ForEach(Array(monthCategories.dropFirst(3).enumerated()), id: \.element.name) { _, cat in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LogEntry.color(for: cat.name))
                            .frame(width: 6, height: 6)
                        Text(cat.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.clTextSecondary)
                        Text("\(percentageOfTotal(cat.hours))%")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
            }
        }
    }

    // MARK: - Donut Chart

    private var donutChart: some View {
        ZStack {
            Circle()
                .stroke(Color.clBorder, lineWidth: donutStroke)

            ForEach(Array(monthCategories.enumerated()), id: \.offset) { index, cat in
                Circle()
                    .trim(
                        from: animateIn ? segmentStart(at: index) : 0,
                        to: animateIn ? segmentEnd(at: index) : 0
                    )
                    .stroke(LogEntry.color(for: cat.name), style: StrokeStyle(lineWidth: donutStroke, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 1) {
                Text("\(Int(totalCategoryHours))")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                Text("h")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
    }

    // MARK: - Callout

    @ViewBuilder
    private func calloutView(index: Int, center: CGPoint) -> some View {
        let cat = monthCategories[index]
        let color = LogEntry.color(for: cat.name)
        let percentage = percentageOfTotal(cat.hours)

        let midFrac = (segmentStart(at: index) + segmentEnd(at: index)) / 2
        let angle = midFrac * 2 * .pi - .pi / 2

        let outerR = donutRadius + donutStroke / 2
        let lineR: CGFloat = 12
        let elbowLen: CGFloat = 14
        let isRight = cos(angle) >= 0

        let startPt = CGPoint(
            x: center.x + cos(angle) * outerR,
            y: center.y + sin(angle) * outerR
        )
        let elbowPt = CGPoint(
            x: center.x + cos(angle) * (outerR + lineR),
            y: center.y + sin(angle) * (outerR + lineR)
        )
        let endPt = CGPoint(
            x: elbowPt.x + (isRight ? elbowLen : -elbowLen),
            y: elbowPt.y
        )

        Path { path in
            path.move(to: startPt)
            path.addLine(to: elbowPt)
            path.addLine(to: endPt)
        }
        .stroke(color.opacity(0.5), lineWidth: 1)

        Circle()
            .fill(color)
            .frame(width: 4, height: 4)
            .position(startPt)

        VStack(alignment: isRight ? .leading : .trailing, spacing: 1) {
            Text(cat.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            HStack(spacing: 3) {
                Text("\(percentage)%")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                Text(DurationFormatter.formatHM(hours: cat.hours))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .lineLimit(1)
            }
            .foregroundStyle(Color.clTextTertiary)
        }
        .fixedSize()
        .position(
            x: endPt.x + (isRight ? 28 : -28),
            y: endPt.y
        )
    }

    // MARK: - Segment Helpers

    /// 0 除算を避けるためのパーセンテージ計算。total が 0 のときは 0% を返す。
    private func percentageOfTotal(_ hours: Double) -> Int {
        guard totalCategoryHours > 0 else { return 0 }
        return Int(hours / totalCategoryHours * 100)
    }

    private func segmentStart(at index: Int) -> Double {
        guard totalCategoryHours > 0 else { return 0 }
        return monthCategories.prefix(index).reduce(0) { $0 + $1.hours } / totalCategoryHours
    }

    private func segmentEnd(at index: Int) -> Double {
        guard totalCategoryHours > 0 else { return 0 }
        let end = monthCategories.prefix(index + 1).reduce(0) { $0 + $1.hours } / totalCategoryHours
        return max(end - 0.005, segmentStart(at: index))
    }

    // MARK: - Weekly Section

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 10) {
                    Button {
                        HapticManager.selection()
                        weekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .buttonStyle(.plain)

                    Text(weekRangeText)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)

                    Button {
                        HapticManager.selection()
                        if weekOffset < 0 { weekOffset += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(weekOffset < 0 ? Color.clTextTertiary : Color.clTextTertiary.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                    .disabled(weekOffset >= 0)
                }

                Spacer()

                Text(weekAverageText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Chart {
                ForEach(weeklyStackedData) { entry in
                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Hours", entry.hours)
                    )
                    .foregroundStyle(by: .value("Category", entry.category))
                    .cornerRadius(2)
                }

                ForEach(Array(weeklyHoursData.enumerated()), id: \.offset) { index, item in
                    PointMark(
                        x: .value("Day", item.day),
                        y: .value("Hours", item.hours)
                    )
                    .opacity(0)
                    .annotation(position: .top, spacing: 2) {
                        Text(String(format: "%.1f", item.hours))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(
                                index == 6 ? Color.clTextPrimary : Color.clTextTertiary
                            )
                    }
                }
            }
            .chartForegroundStyleScale([
                "iOS開発": LogEntry.color(for: "iOS開発"),
                "学習": LogEntry.color(for: "学習"),
                "バグ修正": LogEntry.color(for: "バグ修正"),
                "Web開発": LogEntry.color(for: "Web開発"),
                "デザイン": LogEntry.color(for: "デザイン"),
            ])
            .chartLegend(.hidden)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.system(size: 10))
                        .foregroundStyle(Color.clTextTertiary)
                }
            }
            .frame(height: 110)
        }
    }
}
