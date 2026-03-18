import SwiftUI

struct CLSegmentedControl: View {
    let items: [String]
    @Binding var selection: Int
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        selection = index
                    }
                    HapticManager.selection()
                } label: {
                    Text(item)
                        .font(.system(size: 12, weight: selection == index ? .semibold : .regular))
                        .foregroundStyle(selection == index ? Color.clTextPrimary : Color.clTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selection == index {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.clSurfaceHigh)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.clBorder, lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
                                    .matchedGeometryEffect(id: "segment", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(Color.clSurfaceLow)
        )
    }
}
