import SwiftUI

/// Step 13 (2026-04-14): handle 確定後の完了演出。
/// 1.5s の演出 → 自動 dismiss。粒子 5 粒 (reduce motion 時は非表示)。
struct OnboardingCompletionCelebrationStep: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var iconScale: CGFloat = 0
    @State private var iconRotation: Double = -20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var particlesVisible = false

    private let particleAngles: [Double] = [30, 90, 150, 210, 330]

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    if !reduceMotion {
                        ForEach(Array(particleAngles.enumerated()), id: \.offset) { _, angle in
                            particle(angle: angle)
                        }
                    }

                    Image(systemName: "sparkles")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(Color.clAccent)
                        .scaleEffect(iconScale)
                        .rotationEffect(.degrees(iconRotation))
                }
                .frame(width: 180, height: 180)

                VStack(spacing: 10) {
                    Text("準備完了!")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .tracking(-0.5)
                        .opacity(titleOpacity)

                    Text("つくろぐへようこそ")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.6))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .onAppear(perform: animateIn)
    }

    @ViewBuilder
    private func particle(angle: Double) -> some View {
        let rad = angle * .pi / 180
        let distance: CGFloat = particlesVisible ? 72 : 0
        let x = cos(rad) * distance
        let y = sin(rad) * distance

        Circle()
            .fill(Color.clAccent.opacity(0.85))
            .frame(width: 6, height: 6)
            .offset(x: x, y: y)
            .opacity(particlesVisible ? 0 : 1)
            .scaleEffect(particlesVisible ? 0.3 : 1)
    }

    private func animateIn() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.35)) {
                iconScale = 1
                iconRotation = 0
                titleOpacity = 1
                subtitleOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                HapticManager.light()
                onComplete()
            }
            return
        }

        withAnimation(.spring(duration: 0.7, bounce: 0.4)) {
            iconScale = 1.0
            iconRotation = 0
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.15)) {
            particlesVisible = true
        }
        withAnimation(.spring(duration: 0.6, bounce: 0.15).delay(0.3)) {
            titleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            subtitleOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            HapticManager.light()
            onComplete()
        }
    }
}

#Preview {
    OnboardingCompletionCelebrationStep(onComplete: {})
}
