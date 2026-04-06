import SwiftUI

/// Step 07: アカウント作成促進。
/// 保存した記録カードを見せつつ、アカウント作成の価値を提示。
/// Auth 未実装のため、全ボタンが advance → profileSetup に遷移。
/// 「あとで」はオンボーディングを完了する。
struct OnboardingAccountPromptStep: View {
    let projectName: String
    let durationMinutes: Int
    let categoryName: String
    let onAdvance: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                VStack(spacing: 8) {
                    Text("この記録を")
                    Text("失わないために。")
                }
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .tracking(-0.5)
                .multilineTextAlignment(.center)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 10)

                Text("アカウントを作成すると\n記録がクラウドに安全に保存されます")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.clTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .opacity(appeared ? 0.8 : 0)

                Spacer().frame(height: 28)

                savedCardCompact
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.95)
                    .padding(.horizontal, 40)

                Spacer()

                VStack(spacing: 12) {
                    // Sign in with Apple (primary)
                    Button {
                        HapticManager.medium()
                        onAdvance()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 18, weight: .semibold))
                            Text("Appleでサインイン")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundStyle(Color.clBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Color.clTextPrimary))
                    }
                    .buttonStyle(.plain)

                    // Email (secondary)
                    Button {
                        HapticManager.light()
                        onAdvance()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 15))
                            Text("メールで登録")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundStyle(Color.clTextPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .strokeBorder(Color.clTextPrimary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Skip
                    Button {
                        HapticManager.light()
                        onSkip()
                    } label: {
                        Text("あとで")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .padding(.top, 4)
                }
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
                .padding(.horizontal, 32)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    cardVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    ctaVisible = true
                }
            }
        }
    }

    // MARK: - Saved Card (Compact)

    private var savedCardCompact: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.clCat01)
                .frame(width: 4, height: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(projectName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                    .lineLimit(1)
                Text(categoryName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()

            Text(DurationFormatter.format(minutes: durationMinutes))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color.clTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    OnboardingAccountPromptStep(
        projectName: "つくろぐ iOS",
        durationMinutes: 90,
        categoryName: "開発",
        onAdvance: {},
        onSkip: {}
    )
}
