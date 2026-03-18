import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clAccent,
                                    Color.clAccent.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.clAccent.opacity(0.3), radius: 16, y: 6)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
