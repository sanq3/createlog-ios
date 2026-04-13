import SwiftUI

/// Step 10 (2026-04-14): Sign In 成功直後の 1.5s 祝福演出。
/// accountPrompt → signInCelebration → profileSetup。
/// auto-advance (スキップ不可)。
/// reduce motion 時は fade のみ。
struct OnboardingSignInCelebrationStep: View {
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var checkScale: CGFloat = 0
    @State private var ringScale: CGFloat = 0.6
    @State private var ringOpacity: Double = 0
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.clAccent.opacity(0.2), lineWidth: 2)
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Circle()
                        .fill(Color.clAccent.opacity(0.15))
                        .frame(width: 110, height: 110)
                        .scaleEffect(checkScale)

                    Image(systemName: "checkmark")
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(Color.clAccent)
                        .scaleEffect(checkScale)
                }

                VStack(spacing: 10) {
                    Text("アカウント作成完了!")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .tracking(-0.5)
                        .opacity(titleOpacity)

                    Text("プロフィールを設定しましょう")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.55))
                        .opacity(subtitleOpacity)
                }
            }
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.35)) {
                checkScale = 1
                ringScale = 1
                ringOpacity = 1
                titleOpacity = 1
                subtitleOpacity = 1
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                HapticManager.light()
                onAdvance()
            }
            return
        }

        withAnimation(.spring(duration: 0.55, bounce: 0.35)) {
            checkScale = 1
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.1)) {
            ringScale = 1.3
            ringOpacity = 0
        }
        withAnimation(.spring(duration: 0.6, bounce: 0.15).delay(0.25)) {
            titleOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.45)) {
            subtitleOpacity = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            HapticManager.light()
            onAdvance()
        }
    }
}

#Preview {
    OnboardingSignInCelebrationStep(onAdvance: {})
}
