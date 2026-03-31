import SwiftUI
import Charts

struct ReportDashboardView: View {
    @State private var animateIn = false

    // Mock data
    private let todayHours: Double = 4.25
    private let weekHours: Double = 28.5
    private let monthHours: Double = 58.3

    private let mockCategories: [(name: String, hours: Double)] = [
        ("iOS開発", 24.5),
        ("学習", 12.0),
        ("バグ修正", 8.5),
        ("Web開発", 7.8),
        ("デザイン", 5.5),
    ]

    private var totalCategoryHours: Double {
        mockCategories.reduce(0) { $0 + $1.hours }
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
                    Text("今月のカテゴリ")
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
                    Text("週間の推移")
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
        .navigationTitle("レポート")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    HapticManager.medium()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .light))
                }
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.1).delay(0.1)) {
                animateIn = true
            }
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiItem(hours: animateIn ? todayHours : 0, label: "今日")
            kpiItem(hours: animateIn ? weekHours : 0, label: "今週")
            kpiItem(hours: animateIn ? monthHours : 0, label: "今月")
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

                    ForEach(0..<min(3, mockCategories.count), id: \.self) { index in
                        calloutView(index: index, center: center)
                    }
                    .opacity(animateIn ? 1 : 0)
                }
            }
            .frame(height: 220)

            HStack(spacing: 16) {
                ForEach(Array(mockCategories.dropFirst(3).enumerated()), id: \.element.name) { _, cat in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(LogEntry.color(for: cat.name))
                            .frame(width: 6, height: 6)
                        Text(cat.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.clTextSecondary)
                        Text("\(Int(cat.hours / totalCategoryHours * 100))%")
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

            ForEach(Array(mockCategories.enumerated()), id: \.offset) { index, cat in
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
        let cat = mockCategories[index]
        let color = LogEntry.color(for: cat.name)
        let percentage = Int(cat.hours / totalCategoryHours * 100)

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

    private func segmentStart(at index: Int) -> Double {
        mockCategories.prefix(index).reduce(0) { $0 + $1.hours } / totalCategoryHours
    }

    private func segmentEnd(at index: Int) -> Double {
        let end = mockCategories.prefix(index + 1).reduce(0) { $0 + $1.hours } / totalCategoryHours
        return max(end - 0.005, segmentStart(at: index))
    }

    // MARK: - Weekly Section

    private var weeklySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 10) {
                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .buttonStyle(.plain)

                    Text("3/20 - 3/26")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)

                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Text("avg 4h 18m")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Chart {
                ForEach(MockData.weeklyStackedHours) { entry in
                    BarMark(
                        x: .value("Day", entry.day),
                        y: .value("Hours", entry.hours)
                    )
                    .foregroundStyle(by: .value("Category", entry.category))
                    .cornerRadius(2)
                }

                ForEach(Array(MockData.weeklyHours.enumerated()), id: \.offset) { index, item in
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
