import SwiftUI

/// プロフィール / 投稿 / コメント等で使う共通アバター。
///
/// 表示優先順:
/// 1. `imageData` (オンボーディング中の local preview / PhotosPicker 直後)
/// 2. `imageURL` (Supabase Storage `avatars` の public URL)
/// 3. initials gradient fallback (画像なし or 読み込み失敗時)
struct AvatarView: View {
    let initials: String
    var size: CGFloat = 44
    var status: OnlineStatus = .offline
    var imageURL: URL? = nil
    var imageData: Data? = nil

    private static let gradientTopSaturation: Double = 0.15
    private static let gradientTopBrightness: Double = 0.35
    private static let gradientBottomSaturation: Double = 0.1
    private static let gradientBottomBrightness: Double = 0.2

    private var gradientColors: [Color] {
        let hash = initials.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hue = Double(hash % 360) / 360.0
        return [
            Color(hue: hue, saturation: Self.gradientTopSaturation, brightness: Self.gradientTopBrightness),
            Color(hue: hue, saturation: Self.gradientBottomSaturation, brightness: Self.gradientBottomBrightness)
        ]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            avatarBody
                .frame(width: size, height: size)
                .clipShape(Circle())
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

    @ViewBuilder
    private var avatarBody: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let imageURL {
            AsyncImage(url: imageURL, transaction: Transaction(animation: .easeOut(duration: 0.2))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .empty:
                    initialsFallback
                case .failure:
                    initialsFallback
                @unknown default:
                    initialsFallback
                }
            }
        } else {
            initialsFallback
        }
    }

    private var initialsFallback: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        )
    }
}
