import SwiftUI

struct TodayHeroView: View {
    @State private var animateIn = false
    @State private var displayedTodayMinutes = 0
    @State private var displayedCumulativeMinutes = 0
    @State private var displayedWeekChange = 0.0
    @State private var lastAnimatedMetrics: RecordingHeroMetrics?

    let metrics: RecordingHeroMetrics?
    var pickerHours: Binding<Int>?
    var pickerMinutes: Binding<Int>?

    private static let pickerHeight: CGFloat = 230

    var body: some View {
        VStack(spacing: 0) {
            kpiRow

            if let hours = pickerHours, let minutes = pickerMinutes {
                pickerRow(hours: hours, minutes: minutes)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 0)
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
            kpiItem(minutes: displayedTodayMinutes, referenceMinutes: targetTodayMinutes, label: "recording.today")
            kpiItem(minutes: displayedCumulativeMinutes, referenceMinutes: targetCumulativeMinutes, label: "recording.total")
            weekChangeItem
        }
    }

    private func kpiItem(minutes: Int, referenceMinutes: Int, label: LocalizedStringKey) -> some View {
        return VStack(spacing: 3) {
            DurationKPIValueView(minutes: minutes, referenceMinutes: referenceMinutes)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
                .offset(y: animateIn ? 0 : -14)
                .opacity(animateIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Picker Row (2-component, full width)

    private func pickerRow(hours: Binding<Int>, minutes: Binding<Int>) -> some View {
        DurationPicker(hours: hours, minutes: minutes)
            .frame(height: Self.pickerHeight)
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

            Text("recording.vsLastWeek")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
                .offset(y: animateIn ? 0 : -14)
                .opacity(animateIn ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Formatting

    private var targetTodayMinutes: Int {
        metrics?.todayMinutes ?? displayedTodayMinutes
    }

    private var targetCumulativeMinutes: Int {
        metrics?.cumulativeMinutes ?? displayedCumulativeMinutes
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
