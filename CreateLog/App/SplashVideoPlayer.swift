import SwiftUI
import AVKit
import AVFoundation

/// 起動時スプラッシュで使うボーダレス動画プレイヤー。
/// AVKit の `VideoPlayer` はデフォルトで再生コントロールが出てしまうため、
/// `AVPlayerLayer` を直接 UIViewRepresentable でラップし完全に装飾ゼロで再生する。
/// 再生完了時に `onFinish` を 1 回だけ呼ぶ (重複呼び出し防止は呼び出し側で行う)。
struct SplashVideoPlayer: UIViewRepresentable {
    let url: URL
    let invertColors: Bool
    let onFinish: () -> Void

    func makeUIView(context: Context) -> SplashVideoPlayerView {
        let view = SplashVideoPlayerView()
        view.backgroundColor = invertColors ? .white : .black
        view.playerLayer.videoGravity = .resizeAspect

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)

        if invertColors {
            item.videoComposition = AVVideoComposition(asset: asset, applyingCIFiltersWithHandler: { request in
                let source = request.sourceImage.clampedToExtent()
                // CIColorMatrix で反転 + bias 1.05 により H.264 YUV 丸め誤差を吸収し
                // 背景の「ほぼ白」を完全白に飽和させる
                let output = source.applyingFilter("CIColorMatrix", parameters: [
                    "inputRVector": CIVector(x: -1, y: 0, z: 0, w: 0),
                    "inputGVector": CIVector(x: 0, y: -1, z: 0, w: 0),
                    "inputBVector": CIVector(x: 0, y: 0, z: -1, w: 0),
                    "inputBiasVector": CIVector(x: 1.05, y: 1.05, z: 1.05, w: 0),
                ])
                request.finish(with: output.cropped(to: request.sourceImage.extent), context: nil)
            })
        }

        let player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        player.isMuted = true
        view.playerLayer.player = player

        context.coordinator.player = player
        context.coordinator.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            onFinish()
        }

        player.play()
        return view
    }

    func updateUIView(_ uiView: SplashVideoPlayerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var player: AVPlayer?
        var endObserver: NSObjectProtocol?

        deinit {
            if let endObserver {
                NotificationCenter.default.removeObserver(endObserver)
            }
            player?.pause()
        }
    }
}

/// AVPlayerLayer を layer class として使う専用 UIView。
final class SplashVideoPlayerView: UIView {
    override static var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

/// 起動時に 1 度だけ表示される動画ロゴスプラッシュ画面。
/// `onboarding_wordmark.mp4` (2.17s) を再生し、完了後に `onFinish` を呼ぶ。
/// 動画が見つからない場合は 1.5 秒後に自動で finish する (保険)。
/// 再生中にタップすればスキップ可能。
struct SplashView: View {
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var hasFinished = false

    private var isLight: Bool { colorScheme == .light }

    var body: some View {
        ZStack {
            (isLight ? Color.white : Color.black)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    finish(natural: false)
                }

            if let url = Bundle.main.url(forResource: "onboarding_wordmark", withExtension: "mp4") {
                SplashVideoPlayer(url: url, invertColors: isLight) {
                    finish(natural: true)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            } else {
                Text("CreateLog")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(isLight ? .black : .white)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            finish(natural: true)
                        }
                    }
            }
        }
    }

    private func finish(natural: Bool) {
        guard !hasFinished else { return }
        hasFinished = true
        if !natural {
            HapticManager.light()
        }
        onFinish()
    }
}
