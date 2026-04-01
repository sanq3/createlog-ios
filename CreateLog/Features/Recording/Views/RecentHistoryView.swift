import SwiftUI

struct RecentHistoryView: View {
    let entries: [SDTimeEntry]

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近の記録")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.clTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            if entries.isEmpty {
                emptyState
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        entryRow(entry, index: index)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        Text("まだ記録がありません")
            .font(.system(size: 13))
            .foregroundStyle(Color.clTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }

    private func entryRow(_ entry: SDTimeEntry, index: Int) -> some View {
        let color = LogEntry.color(for: entry.categoryName)

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.projectName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                Text(entry.categoryName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(RecordingViewModel.formatDuration(entry.durationMinutes))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                Text(formatTime(entry.startDate))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.clSurfaceLow.opacity(0.3))
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .animation(
            .spring(duration: 0.35, bounce: 0.15).delay(Double(index) * 0.04),
            value: appeared
        )
        .onAppear {
            appeared = true
        }
    }

    private func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
