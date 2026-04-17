import SwiftUI

struct ActivityHeatmap: View {
    private let weeks = 4
    private let days = 7
    private let dotSize: CGFloat = 10
    private let dotSpacing: CGFloat = 4

    private let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    // Mock: 4 weeks x 7 days of activity hours
    private let data: [[Double]] = [
        [0, 2.5, 0, 0.5, 3.2, 0, 0],
        [4.1, 1.8, 3.5, 0, 2.0, 0, 1.2],
        [3.0, 4.8, 0, 6.2, 5.1, 0, 4.5],
        [3.2, 4.8, 3.5, 6.2, 0, 0, 0],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Day labels + grid
            HStack(alignment: .top, spacing: dotSpacing) {
                // Day labels column
                VStack(spacing: dotSpacing) {
                    ForEach(0..<days, id: \.self) { day in
                        Text(dayLabels[day])
                            .font(.system(size: 9))
                            .foregroundStyle(Color.clTextTertiary)
                            .frame(width: 14, height: dotSize)
                    }
                }

                // Week columns
                ForEach(0..<weeks, id: \.self) { week in
                    VStack(spacing: dotSpacing) {
                        ForEach(0..<days, id: \.self) { day in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(dotColor(hours: data[week][day]))
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                }

                Spacer()

                // Legend
                VStack(alignment: .trailing, spacing: 4) {
                    legendItem(color: dotColor(hours: 0), label: "0h")
                    legendItem(color: dotColor(hours: 1.5), label: "1-2h")
                    legendItem(color: dotColor(hours: 3.5), label: "3h+")
                }
            }
        }
    }

    private func dotColor(hours: Double) -> Color {
        if hours <= 0 {
            return Color.clSurfaceHigh
        } else if hours < 3 {
            return Color.clAccent.opacity(0.4)
        } else {
            return Color.clAccent
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.clTextTertiary)
        }
    }
}
