import SwiftUI

/// オンボーディング後半 (1 画面 1 質問) の共通レイアウト shell。
/// 上半分: タイトル + サブタイトル + 入力 UI + 続けるボタン + スキップ (任意 step のみ)
/// 下半分: 下部 preview card (profile or product)
///
/// 3 段フェード (title → input → CTA) と スキップ時のフェード + advance を統一。
struct OnboardingQuestionShell<Input: View, Preview: View>: View {
    let title: String
    let subtitle: String?
    let isOptional: Bool
    let canAdvance: Bool
    let isSaving: Bool
    let errorMessage: String?
    let onContinue: () -> Void
    let onSkip: (() -> Void)?
    @ViewBuilder let input: () -> Input
    @ViewBuilder let preview: () -> Preview

    @State private var titleVisible = false
    @State private var inputVisible = false
    @State private var ctaVisible = false
    @State private var previewVisible = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 72)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.clTextPrimary.opacity(0.55))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 32)
                .opacity(titleVisible ? 1 : 0)
                .offset(y: titleVisible ? 0 : 12)

                Spacer().frame(height: 32)

                input()
                    .padding(.horizontal, 24)
                    .opacity(inputVisible ? 1 : 0)
                    .offset(y: inputVisible ? 0 : 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.clError)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 10)
                }

                Spacer()

                // Preview (下半分固定)
                preview()
                    .padding(.horizontal, 24)
                    .opacity(previewVisible ? 1 : 0)
                    .offset(y: previewVisible ? 0 : 24)

                Spacer().frame(height: 24)

                // CTA (前半ステップと共通の OnboardingPrimaryCTA を使用)
                VStack(spacing: 10) {
                    OnboardingPrimaryCTA(
                        title: "続ける",
                        isEnabled: canAdvance,
                        isLoading: isSaving,
                        disabledStyle: .dimmed,
                        action: onContinue
                    )

                    if isOptional, let onSkip {
                        Button {
                            HapticManager.light()
                            onSkip()
                        } label: {
                            Text("あとで設定する")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary.opacity(0.45))
                        }
                        .disabled(isSaving)
                    }
                }
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 12)

                Spacer().frame(height: 36)
            }
        }
        .onAppear(perform: animateIn)
    }

    private func animateIn() {
        withAnimation(.spring(duration: 0.6, bounce: 0.15).delay(0.05)) {
            titleVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                inputVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                previewVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.spring(duration: 0.5, bounce: 0.2)) {
                ctaVisible = true
            }
        }
    }
}

// MARK: - Labeled input row (共通入力スタイル)

struct OnboardingLabeledInput<Content: View>: View {
    let label: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let label {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.55))
            }
            content()
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Color.clTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.clSurfaceHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
                )
        }
    }
}
