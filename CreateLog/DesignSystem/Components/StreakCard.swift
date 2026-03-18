import SwiftUI

struct StreakCard: View {
    let days: Int
    let weekProgress: [Bool]

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.clAccent)
                    .symbolEffect(.bounce, value: days)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(days)日連続")
                        .font(.clNumber)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()

                    Text("パーソナルベスト更新中")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    HStack(spacing: 3) {
                        ForEach(Array(weekProgress.enumerated()), id: \.offset) { index, completed in
                            Circle()
                                .fill(
                                    completed
                                        ? (index == weekProgress.count - 1
                                            ? Color.clAccent
                                            : Color.clAccent.opacity(0.4))
                                        : Color.clSurfaceLow
                                )
                                .frame(width: 8, height: 8)
                                .shadow(
                                    color: index == weekProgress.count - 1 && completed
                                        ? Color.clAccent.opacity(0.3) : .clear,
                                    radius: 4
                                )
                        }
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
        }
    }
}
