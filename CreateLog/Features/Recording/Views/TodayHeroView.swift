import SwiftUI

struct TodayHeroView: View {
    @State private var animateIn = false

    let todayMinutes: Int
    let cumulativeMinutes: Int
    let weekChange: Double?
    let breakdown: [CategoryBreakdownItem]

    var body: some View {
        VStack(spacing: 16) {
            kpiRow

            if breakdown.count >= 2 {
                categoryBar
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
        .onAppear {
            withAnimation(.spring(duration: 1.0, bounce: 0.1).delay(0.1)) {
                animateIn = true
            }
        }
    }

    // MARK: - KPI Row (same structure as ReportDashboardView)

    private var kpiRow: some View {
        HStack(spacing: 0) {
            kpiItem(hours: animateIn ? Double(todayMinutes) / 60.0 : 0, label: "今日")
            kpiItem(hours: animateIn ? Double(cumulativeMinutes) / 60.0 : 0, label: "累計")
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
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Week Change (same visual structure as kpiItem)

    private var weekChangeItem: some View {
        VStack(spacing: 3) {
            if let change = weekChange, animateIn {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 13, weight: .bold))
                    Text(formatPercent(change))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(change >= 0 ? Color.clSuccess : Color.clTextTertiary)
            } else {
                Text("--")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.clTextTertiary)
            }
            Text("先週比")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Category Bar

    private var categoryBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(breakdown) { item in
                    let ratio = todayMinutes > 0
                        ? CGFloat(item.minutes) / CGFloat(todayMinutes)
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

    private func formatPercent(_ value: Double) -> String {
        let pct = Int(abs(value) * 100)
        return "\(pct)%"
    }
}
