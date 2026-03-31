import SwiftUI

struct TodayHeroView: View {
    let todayMinutes: Int
    let cumulativeMinutes: Int
    let weekChange: Double?
    let breakdown: [CategoryBreakdownItem]

    @State private var animate = false

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                kpiColumn(
                    minutes: animate ? todayMinutes : 0,
                    label: "今日"
                )

                kpiColumn(
                    minutes: animate ? cumulativeMinutes : 0,
                    label: "累計"
                )

                weekChangeColumn
            }

            if !breakdown.isEmpty {
                categoryBar
            }
        }
        .padding(.vertical, 20)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.1)) {
                animate = true
            }
        }
        .onChange(of: todayMinutes) {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                animate = true
            }
        }
    }

    // MARK: - KPI Column

    private func kpiColumn(minutes: Int, label: String) -> some View {
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

    // MARK: - Week Change

    private var weekChangeColumn: some View {
        VStack(spacing: 3) {
            if let change = weekChange, animate {
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

                    RoundedRectangle(cornerRadius: 2)
                        .fill(LogEntry.color(for: item.name))
                        .frame(width: animate ? max(geo.size.width * ratio - 2, 4) : 0)
                }
            }
            .animation(.spring(duration: 0.5, bounce: 0.15), value: animate)
        }
        .frame(height: 4)
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }

    // MARK: - Formatting

    private func formatPercent(_ value: Double) -> String {
        let pct = Int(abs(value) * 100)
        return "\(pct)%"
    }
}
