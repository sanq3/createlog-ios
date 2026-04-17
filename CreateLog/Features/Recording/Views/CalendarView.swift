import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: CalendarViewModel?

    private let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    private var today: Int {
        Calendar.current.component(.day, from: Date())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Month header
                HStack {
                    Button {
                        HapticManager.selection()
                        viewModel?.goToPreviousMonth()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer()

                    Text(viewModel?.monthTitle ?? "")
                        .font(.clTitle)
                        .foregroundStyle(Color.clTextPrimary)

                    Spacer()

                    Button {
                        HapticManager.selection()
                        viewModel?.goToNextMonth()
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
                if let viewModel {
                    calendarGrid(viewModel: viewModel)
                }

                // Monthly summary
                if let viewModel {
                    monthlySummary(viewModel: viewModel)
                        .padding(.horizontal, 20)
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .task {
            if viewModel == nil {
                viewModel = CalendarViewModel(
                    modelContext: modelContext,
                    statsRepository: dependencies.statsRepository
                )
                viewModel?.loadMonth()
            }
        }
    }

    @ViewBuilder
    private func calendarGrid(viewModel: CalendarViewModel) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(0..<viewModel.firstDayOffset, id: \.self) { _ in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
            }

            ForEach(1...viewModel.daysInMonth, id: \.self) { day in
                let hours = viewModel.dayHours[day] ?? 0
                let isToday = isCurrentMonth(viewModel: viewModel) && day == today
                let hasData = hours > 0
                let intensity = min(hours / 8.0, 1.0)

                Button {
                    HapticManager.selection()
                    viewModel.selectDay(day)
                } label: {
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
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func monthlySummary(viewModel: CalendarViewModel) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(viewModel.displayMonth)月のサマリー")
                    .font(.clHeadline)
                    .foregroundStyle(Color.clTextSecondary)

                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text(String(format: "%.1fh", Double(viewModel.monthTotalMinutes) / 60.0))
                            .font(.clNumber)
                            .foregroundStyle(Color.clTextPrimary)
                        Text("合計時間")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    VStack(alignment: .leading) {
                        Text(viewModel.topCategory.isEmpty ? "-" : viewModel.topCategory)
                            .font(.clNumber)
                            .foregroundStyle(Color.clTextPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("最多カテゴリ")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    VStack(alignment: .leading) {
                        Text(viewModel.bestDay > 0 ? "\(viewModel.displayMonth)/\(viewModel.bestDay)" : "-")
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
    }

    private func isCurrentMonth(viewModel: CalendarViewModel) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        return viewModel.displayYear == calendar.component(.year, from: now) &&
               viewModel.displayMonth == calendar.component(.month, from: now)
    }
}
