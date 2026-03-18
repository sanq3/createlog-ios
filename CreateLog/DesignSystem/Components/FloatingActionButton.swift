import SwiftUI

struct FloatingActionButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.medium()
            action()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.clTextPrimary)
                .frame(width: 52, height: 52)
                .glassBackground(cornerRadius: 26)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
