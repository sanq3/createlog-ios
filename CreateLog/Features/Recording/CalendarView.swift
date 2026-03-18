import SwiftUI

struct CalendarView: View {
    private let daysInMonth = 31
    private let firstDayOffset = 5 // 3月は土曜日始まり（0=月）
    private let today = 18

    private let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    // ダミー: 各日の作業時間（0 = 記録なし）
    private let dayHours: [Int: Double] = [
        1: 3.2, 2: 4.1, 3: 2.8, 5: 5.0, 6: 3.5,
        8: 4.2, 9: 3.8, 10: 5.5, 11: 4.0, 12: 6.1,
        15: 3.9, 16: 4.5, 17: 5.2, 18: 4.5
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month header
                HStack {
                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer()

                    Text("2026年3月")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Spacer()

                    Button {
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Day labels
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 3) {
                    ForEach(dayLabels, id: \.self) { day in
                        Text(day)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)

                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                    // Empty cells for offset
                    ForEach(0..<firstDayOffset, id: \.self) { _ in
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                    }

                    // Days
                    ForEach(1...daysInMonth, id: \.self) { day in
                        let hours = dayHours[day] ?? 0
                        let isToday = day == today
                        let hasData = hours > 0
                        let intensity = min(hours / 8.0, 1.0)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    hasData
                                        ? Color.clAccent.opacity(0.1 + intensity * 0.3)
                                        : Color.clear
                                )
                                .overlay(
                                    isToday
                                        ? RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.clAccent.opacity(0.4), lineWidth: 1.5)
                                        : nil
                                )

                            Text("\(day)")
                                .font(.clCaption)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(
                                    isToday ? Color.clTextPrimary
                                    : hasData ? Color.clTextPrimary
                                    : Color.clTextTertiary
                                )
                        }
                        .aspectRatio(1, contentMode: .fit)
                    }
                }
                .padding(.horizontal, 20)

                // Monthly summary
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3月のサマリー")
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextSecondary)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("58.3h")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("合計時間")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            VStack(alignment: .leading) {
                                Text("iOS開発")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("最多カテゴリ")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            VStack(alignment: .leading) {
                                Text("3/12")
                                    .font(.clNumber)
                                    .foregroundStyle(Color.clTextPrimary)
                                Text("ベストデイ")
                                    .font(.clCaption)
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
    }
}
