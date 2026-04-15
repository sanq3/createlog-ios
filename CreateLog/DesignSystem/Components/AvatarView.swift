import SwiftUI
import NukeUI

/// プロフィール / 投稿 / コメント等で使う共通アバター。
///
/// 表示優先順:
/// 1. `imageData` (オンボーディング中の local preview / PhotosPicker 直後)
/// 2. `imageURL` (Supabase Storage `avatars` の public URL、NukeUI `LazyImage` で 3-tier cache)
/// 3. initials gradient fallback (画像なし or 読み込み失敗時)
///
/// 2026-04-16: `AsyncImage` → NukeUI `LazyImage` に置換。
/// Nuke 13.0 の 3-tier cache (memory rendered / memory raw / disk LRU) で
/// avatar flicker 根絶 (Bluesky/Threads/Instagram 同等品質)。`AsyncImage` は Apple が 2021 から
/// cache 制御を改善しておらず production 品質に不足 (Paul Hudson "What's still missing")。
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
            // NukeUI `LazyImage`: 3-tier cache から即 hit した画像は同期的に描画 (flicker ゼロ)。
            // Memory miss & disk hit 時のみ短時間 placeholder (initials gradient) → fade で切替。
            LazyImage(url: imageURL) { state in
                if let image = state.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    initialsFallback
                }
            }
            .transition(.opacity)
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
