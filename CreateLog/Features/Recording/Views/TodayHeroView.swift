import SwiftUI

struct TodayHeroView: View {
    @State private var animateIn = false
    @State private var displayedTodayMinutes = 0
    @State private var displayedCumulativeMinutes = 0
    @State private var displayedWeekChange = 0.0
    @State private var lastAnimatedMetrics: RecordingHeroMetrics?

    let metrics: RecordingHeroMetrics?

    var body: some View {
        VStack(spacing: 16) {
            kpiRow

            if currentBreakdown.count >= 2 {
                categoryBar
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .onAppear {
            resetDisplayedMetrics()
            if let metrics {
                animateMetrics(to: metrics)
            }
        }
        .onChange(of: metrics) { _, newMetrics in
            guard let newMetrics else { return }
            animateMetrics(to: newMetrics)
        }
        .onDisappear {
            resetDisplayedMetrics()
        }
    }

    // MARK: - KPI Row

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiItem(hours: Double(displayedTodayMinutes) / 60.0, label: "今日")
            kpiItem(hours: Double(displayedCumulativeMinutes) / 60.0, label: "累計")
            weekChangeItem
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
                .offset(y: animateIn ? 0 : -14)
                .opacity(animateIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week Change

    private var weekChangeItem: some View {
        let isPositive = displayedWeekChange >= 0

        return VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 13, weight: .bold))
                Text(formatPercent(displayedWeekChange))
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(isPositive ? Color.clSuccess : Color.clTextTertiary)

            Text("先週比")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
                .offset(y: animateIn ? 0 : -14)
                .opacity(animateIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(currentBreakdown) { item in
                    let ratio = displayedTodayMinutes > 0
                        ? CGFloat(item.minutes) / CGFloat(displayedTodayMinutes)
                        : 0

                    RoundedRectangle(cornerRadius: 3)
                        .fill(LogEntry.color(for: item.name))
                        .frame(width: animateIn ? max(geo.size.width * ratio - 2, 4) : 0)
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.15), value: animateIn)
        }
        .frame(height: 5)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .padding(.horizontal, 12)
    }

    // MARK: - Formatting

    private var currentBreakdown: [CategoryBreakdownItem] {
        metrics?.breakdown ?? []
    }

    private func formatPercent(_ value: Double) -> String {
        let pct = Int(abs(value) * 100)
        return "\(pct)%"
    }

    private func resetDisplayedMetrics() {
        animateIn = false
        displayedTodayMinutes = 0
        displayedCumulativeMinutes = 0
        displayedWeekChange = 0
        lastAnimatedMetrics = nil
    }

    private func animateMetrics(to metrics: RecordingHeroMetrics) {
        guard lastAnimatedMetrics != metrics else { return }
        lastAnimatedMetrics = metrics

        withAnimation(.spring(duration: 1.0, bounce: 0.1).delay(0.1)) {
            animateIn = true
            displayedTodayMinutes = metrics.todayMinutes
            displayedCumulativeMinutes = metrics.cumulativeMinutes
            displayedWeekChange = metrics.weekChange ?? 0
        }
    }
}
