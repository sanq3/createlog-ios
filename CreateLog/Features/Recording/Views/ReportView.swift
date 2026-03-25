import SwiftUI

struct ReportView: View {
    @State private var periodIndex = 1
    @State private var animateNumbers = false

    private let totalCategories: Double = 28.5

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Hero number
                VStack(spacing: 4) {
                    Text("今週のあなた")
                        .font(.clCaption)
                        .foregroundStyle(Color.clTextTertiary)

                    Text(animateNumbers ? "28.5" : "0.0")
                        .font(.clBigNumber)
                        .foregroundStyle(Color.clTextPrimary)
                        .tabularNumbers()
                        .contentTransition(.numericText())

                    Text("時間")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextSecondary)
                }
                .padding(.top, 16)

                // Period selector
                HStack(spacing: 4) {
                    ForEach(Array(["今日", "今週", "今月", "累計"].enumerated()), id: \.offset) { index, label in
                        Button {
                            withAnimation(.snappy(duration: 0.3)) {
                                periodIndex = index
                            }
                            HapticManager.selection()
                        } label: {
                            Text(label)
                                .font(.clCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(periodIndex == index ? Color.clTextPrimary : Color.clTextTertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    periodIndex == index ? Color.clSurfaceHigh : Color.clear,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Streak
                StreakCard(
                    days: 12,
                    weekProgress: [true, true, true, true, true, true, true]
                )
                .padding(.horizontal, 20)

                // Stats grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatBadge(value: "4.5h", label: "今日", change: "↑ 1.2h 昨日比")
                    StatBadge(value: "28.5h", label: "今週", change: "↑ 3h 先週比")
                    StatBadge(value: "1,240h", label: "累計", change: "上位 12%")
                    StatBadge(value: "4.1h", label: "日平均", change: "↓ 0.3h 先週比", changePositive: false)
                }
                .padding(.horizontal, 20)

                // Weekly chart
                WeeklyChart(data: MockData.weeklyHours)
                    .padding(.horizontal, 20)

                // Category breakdown
                CategoryBreakdown(categories: MockData.categoryItems)
                    .padding(.horizontal, 20)

                // Share button
                Button {
                    HapticManager.medium()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                        Text("レポートをシェア")
                            .font(.clHeadline)
                    }
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .onAppear {
            withAnimation(.spring(duration: 0.8)) {
                animateNumbers = true
            }
        }
    }
}
