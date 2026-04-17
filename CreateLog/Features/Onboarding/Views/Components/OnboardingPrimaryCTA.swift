import SwiftUI

/// オンボーディング全 Step 共通の primary CTA ボタン。
///
/// 背景 `clTextPrimary` / 文字 `clBackground` の反転カプセル (ライト=黒背景+白文字、ダーク=白背景+黒文字)。
/// 各 Step で直書きしていた CTA を単一コンポーネントに集約し、トークン選択のズレ (例: clAccent+白文字で
/// ダーク時に視認不能になった事故) を構造的に防ぐ。
///
/// 新しい Step に CTA を足したくなったら、このコンポーネントを使え。直書きコピペ禁止。
struct OnboardingPrimaryCTA: View {
    enum DisabledStyle {
        /// 無効時に opacity 0.3 で暗くして残す (Platform / TechStack 等の固定配置)
        case dimmed
        /// 無効時に非表示 + spring-up で登場 (ProjectName 等の入力依存)
        case hidden
    }

    let title: LocalizedStringKey
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var disabledStyle: DisabledStyle = .dimmed
    let action: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 0)
            Button {
                guard isEnabled, !isLoading else { return }
                HapticManager.light()
                action()
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .tint(Color.clBackground)
                            .scaleEffect(0.85)
                    }
                    Text(isLoading ? LocalizedStringKey("common.saving") : title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clBackground)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 16)
                .background(Capsule().fill(backgroundFill))
            }
            .buttonStyle(.plain)
            .allowsHitTesting(isEnabled && !isLoading)
            .opacity(hiddenOffscreen ? 0 : 1)
            .offset(y: hiddenOffscreen ? 24 : 0)
            .blur(radius: hiddenOffscreen ? 4 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.25), value: isEnabled)
            Spacer(minLength: 0)
        }
    }

    private var backgroundFill: Color {
        switch disabledStyle {
        case .dimmed:
            return Color.clTextPrimary.opacity(isEnabled ? 1 : 0.3)
        case .hidden:
            return Color.clTextPrimary
        }
    }

    private var hiddenOffscreen: Bool {
        disabledStyle == .hidden && !isEnabled
    }
}

#Preview("enabled") {
    OnboardingPrimaryCTA(title: "続ける", action: {})
        .padding()
}

#Preview("disabled (dimmed)") {
    OnboardingPrimaryCTA(title: "続ける", isEnabled: false, action: {})
        .padding()
}

#Preview("loading") {
    OnboardingPrimaryCTA(title: "続ける", isLoading: true, action: {})
        .padding()
}
