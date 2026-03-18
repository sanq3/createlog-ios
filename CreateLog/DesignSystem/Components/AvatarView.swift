import SwiftUI

enum OnlineStatus {
    case online, coding, offline

    var color: Color {
        switch self {
        case .online: return .clSuccess
        case .coding: return .clRecording
        case .offline: return .clear
        }
    }
}

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 40
    var status: OnlineStatus = .offline

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clSurfaceHigh, Color.clSurfaceLow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.35, weight: .semibold))
                        .foregroundStyle(Color.clTextSecondary)
                )

            if status != .offline {
                Circle()
                    .fill(status.color)
                    .frame(width: size * 0.3, height: size * 0.3)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.clBackground, lineWidth: 2)
                    )
                    .shadow(color: status.color.opacity(0.5), radius: 4)
            }
        }
    }
}
