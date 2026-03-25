import SwiftUI

struct AvatarView: View {
    let initials: String
    var size: CGFloat = 44
    var status: OnlineStatus = .offline

    private var gradientColors: [Color] {
        let hash = initials.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hue = Double(hash % 360) / 360.0
        return [
            Color(hue: hue, saturation: 0.15, brightness: 0.35),
            Color(hue: hue, saturation: 0.1, brightness: 0.2)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.08), .white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay(
                    Text(initials)
                        .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                )

            if status != .offline {
                Circle()
                    .fill(status.color)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.clBackground, lineWidth: 2.5)
                    )
                    .shadow(color: status.color.opacity(0.6), radius: 6, y: 0)
            }
        }
    }
}
