import SwiftUI

/// Step 03: 「あなたのプロジェクトを登録してみましょう」
/// blur → sharp で登場。タップで次へ。
struct OnboardingTutorialIntroStep: View {
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var hintVisible = false
    @State private var hintPulse = false

    var body: some View {
        ZStack {
            Color.clBackground
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    guard hintVisible else { return }
                    HapticManager.light()
                    onAdvance()
                }

            VStack(spacing: 0) {
                Spacer()

                Text("あなたのプロジェクトを\n登録してみましょう")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .blur(radius: appeared ? 0 : 10)

                Spacer()

                Text("タップして続ける")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(hintVisible ? (hintPulse ? 0.9 : 0.4) : 0)
                    .padding(.bottom, 48)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.08).delay(0.2)) {
                appeared = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.4)) {
                hintVisible = true
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true).delay(1.6)) {
                hintPulse = true
            }
        }
    }
}

#Preview {
    OnboardingTutorialIntroStep(onAdvance: {})
}
