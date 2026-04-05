import SwiftUI

/// Step 02: タグライン 1 文。
/// 「作ったことを、残していく。」を 28pt で表示。他に一切何もない。
/// 2 行構成で、1 行目と 2 行目を順にフェードインさせる (Headspace onboarding 流)。
/// 2 秒後にタップで進む。
struct OnboardingTaglineStep: View {
    let onAdvance: () -> Void

    @State private var firstLine = false
    @State private var secondLine = false
    @State private var hintVisible = false

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

            VStack(spacing: 6) {
                Text("作ったことを、")
                    .opacity(firstLine ? 1 : 0)
                    .offset(y: firstLine ? 0 : 10)
                    .blur(radius: firstLine ? 0 : 4)

                Text("残していく。")
                    .opacity(secondLine ? 1 : 0)
                    .offset(y: secondLine ? 0 : 10)
                    .blur(radius: secondLine ? 0 : 4)
            }
            .font(.system(size: 28, weight: .semibold, design: .default))
            .foregroundStyle(Color.clTextPrimary)
            .tracking(-0.5)

            VStack {
                Spacer()
                Text("タップして続ける")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
                    .opacity(hintVisible ? 0.7 : 0)
                    .padding(.bottom, 48)
            }
            .allowsHitTesting(false)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.35)) {
                firstLine = true
            }
            withAnimation(.spring(duration: 0.9, bounce: 0.15).delay(0.85)) {
                secondLine = true
            }
            withAnimation(.easeOut(duration: 0.6).delay(1.8)) {
                hintVisible = true
            }
        }
    }
}

#Preview {
    OnboardingTaglineStep(onAdvance: {})
}
