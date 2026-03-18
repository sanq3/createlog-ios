import SwiftUI

struct CLSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        selection = index
                    }
                    HapticManager.selection()
                } label: {
                    Text(item)
                        .font(.clHeadline)
                        .foregroundStyle(selection == index ? Color.clTextPrimary : Color.clTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == index
                                ? Color.clSurfaceHigh
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .shadow(
                            color: selection == index ? .black.opacity(0.1) : .clear,
                            radius: 4, y: 2
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
    }
}
