import SwiftUI

/// Step 05: プロダクトの名前は？ テキスト入力。
/// 選択式ステップ (tag/duration) の後に配置される唯一のテキスト入力。
/// 入力が空でない時、「続ける」ボタンが下から spring-up する。
struct OnboardingProjectNameStep: View {
    @Binding var projectName: String
    let canAdvance: Bool
    let onAdvance: () -> Void

    @FocusState private var focused: Bool
    @State private var appeared = false
    @State private var underlineWidth: CGFloat = 0

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: 120)

                Text("プロダクトの名前は？")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 40)

                VStack(alignment: .leading, spacing: 14) {
                    TextField("", text: $projectName, prompt:
                        Text("例 つくろぐ iOS")
                            .foregroundStyle(Color.clTextTertiary.opacity(0.6))
                    )
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tint(Color.clTextPrimary)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit {
                        if canAdvance { advance() }
                    }

                    GeometryReader { geo in
                        Rectangle()
                            .fill(Color.clTextPrimary)
                            .frame(width: underlineWidth == 0 ? 0 : geo.size.width, height: 2)
                            .animation(.spring(duration: 0.6, bounce: 0.2), value: underlineWidth)
                    }
                    .frame(height: 2)
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                Spacer()

                // 続けるボタン (入力があれば spring-up)
                HStack {
                    Spacer()
                    Button {
                        advance()
                    } label: {
                        Text("続ける")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.clBackground)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 16)
                            .background(
                                Capsule()
                                    .fill(Color.clTextPrimary)
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(canAdvance ? 1 : 0)
                    .offset(y: canAdvance ? 0 : 24)
                    .blur(radius: canAdvance ? 0 : 4)
                    .animation(.spring(duration: 0.5, bounce: 0.25), value: canAdvance)
                    Spacer()
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            // Underline grows after text lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                underlineWidth = 1
            }
            // Auto-focus for keyboard
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focused = true
            }
        }
    }

    private func advance() {
        HapticManager.light()
        focused = false
        onAdvance()
    }
}

#Preview {
    OnboardingProjectNameStep(
        projectName: .constant("つくろぐ iOS"),
        canAdvance: true,
        onAdvance: {}
    )
}
