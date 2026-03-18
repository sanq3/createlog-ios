import SwiftUI

struct ActionButton: View {
    let icon: String
    var count: Int? = nil
    var isActive: Bool = false
    var activeColor: Color = .clAccent
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                isPressed = true
            }
            HapticManager.light()
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.snappy(duration: 0.2)) {
                    isPressed = false
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .scaleEffect(isPressed ? 1.3 : 1.0)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(.clCaption)
                        .tabularNumbers()
                }
            }
            .foregroundStyle(isActive ? activeColor : Color.clTextTertiary)
            .padding(.vertical, 6)
            .padding(.trailing, 12)
        }
        .buttonStyle(.plain)
    }
}
