import SwiftUI
import Charts

struct WeeklyChart: View {
    let data: [(day: String, hours: Double)]
    var todayIndex: Int = 6

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("recording.weeklyTrend")
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextSecondary)

                Chart(Array(data.enumerated()), id: \.offset) { index, item in
                    BarMark(
                        x: .value("Day", item.day),
                        y: .value("Hours", item.hours)
                    )
                    .foregroundStyle(
                        index == todayIndex
                            ? Color.clAccent
                            : Color.clAccent.opacity(0.3)
                    )
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let hours = value.as(Double.self) {
                                Text(DurationFormatter.formatAxisLabel(hours: hours))
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .frame(height: 140)
            }
        }
    }
}
