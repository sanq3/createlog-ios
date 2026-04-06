import SwiftUI

struct TimelineBlockView: View {
    let entry: LogEntry

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(entry.categoryColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: entry.categoryIcon)
                        .font(.system(size: 10))
                    Text(entry.categoryName)
                        .font(.system(size: 11, weight: .medium))

                    if entry.isAutoTracked {
                        Circle()
                            .fill(Color.clTextTertiary)
                            .frame(width: 5, height: 5)
                    }
                }
                .foregroundStyle(entry.categoryColor)

                Text(entry.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)

                HStack(spacing: 6) {
                    Text(entry.timeRangeString)
                        .font(.system(size: 11, design: .monospaced))
                    Text(entry.durationString)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.leading, 10)

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.trailing, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(entry.categoryColor.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(entry.categoryColor.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
