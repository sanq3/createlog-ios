import SwiftUI

struct TagChipsView: View {
    let tags: [SDProject]
    let selectedTag: SDProject?
    let onTagTapped: (SDProject) -> Void
    let onTagLongPressed: (SDProject) -> Void
    let onAddTapped: () -> Void

    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(tags.enumerated()), id: \.element.id) { index, tag in
                tagCell(tag: tag, index: index)
            }

            addCell
        }
        .padding(.horizontal, 16)
        .onAppear {
            withAnimation(.spring(duration: 0.4, bounce: 0.15)) {
                appeared = true
            }
        }
    }

    private func tagCell(tag: SDProject, index: Int) -> some View {
        let color = RecordingViewModel.colorForTag(tag)
        let isSelected = selectedTag?.id == tag.id

        return Button {
            onTagTapped(tag)
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 24)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tag.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineLimit(1)
                    if let cat = tag.category {
                        Text(cat.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? color.opacity(0.1) : color.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(
                                isSelected ? color.opacity(0.4) : color.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
        }
        .buttonStyle(.bounce)
        .onLongPressGesture(minimumDuration: 0.5) {
            onTagLongPressed(tag)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(
            .spring(duration: 0.3, bounce: 0.15).delay(Double(index) * 0.03),
            value: appeared
        )
        .animation(.spring(duration: 0.2, bounce: 0.15), value: isSelected)
    }

    private var addCell: some View {
        Button {
            onAddTapped()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                Text("追加")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(Color.clTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
            )
        }
        .buttonStyle(.bounce)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(duration: 0.3, bounce: 0.15).delay(Double(tags.count) * 0.03),
            value: appeared
        )
    }
}
