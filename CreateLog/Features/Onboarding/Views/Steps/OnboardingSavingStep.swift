import SwiftUI

/// Step 07: 保存演出。SDProject (マイプロダクト) が保存された後のフィードバック。
/// カードはプロフィールのマイプロダクトと同じ形式。
struct OnboardingSavingStep: View {
    let projectName: String
    let platform: String
    let languages: [String]
    let onAdvance: () -> Void

    @State private var showSaving = false
    @State private var savedText = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Text("保存中")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.4))
                        .opacity(showSaving && !savedText ? 1 : 0)
                        .blur(radius: savedText ? 6 : 0)

                    Text("保存した")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .opacity(savedText ? 1 : 0)
                        .scaleEffect(savedText ? 1 : 0.92)
                }
                .tracking(-0.5)

                // マイプロダクト形式カード
                serviceCard
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.9)
                    .blur(radius: cardVisible ? 0 : 10)
                    .padding(.horizontal, 32)

                Spacer()

                OnboardingPrimaryCTA(
                    title: "続ける",
                    disabledStyle: .dimmed,
                    action: onAdvance
                )
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.1)) {
                showSaving = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                HapticManager.success()
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    savedText = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                withAnimation(.spring(duration: 0.8, bounce: 0.22)) {
                    cardVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                withAnimation(.spring(duration: 0.55, bounce: 0.25)) {
                    ctaVisible = true
                }
            }
        }
    }

    // MARK: - マイプロダクト形式カード

    private var serviceCard: some View {
        HStack(spacing: 14) {
            // アイコン (頭文字 + カラー)
            let initial = String(projectName.prefix(1))
            Text(initial)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Self.iconColor(for: projectName))
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(projectName)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineLimit(1)

                    Spacer()

                    // Right slot: 将来レビューが入る位置。onboarding 時点では platform + 言語を表示
                    Text(languageSummary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                        .lineLimit(1)
                }

                Text("アカウント作成後に詳細を設定できます")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.3))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
    }

    private var languageSummary: String {
        let parts = [platform] + languages.prefix(3).map { $0 }
        return parts.joined(separator: " / ")
    }

    /// SDProject+Theme と同じパレットで名前ベースの色生成
    private static func iconColor(for name: String) -> Color {
        let palette: [(Double, Double, Double)] = [
            (0.20, 0.25, 0.45), (0.25, 0.15, 0.35), (0.15, 0.20, 0.32),
            (0.18, 0.28, 0.25), (0.28, 0.18, 0.22), (0.22, 0.22, 0.35),
        ]
        let index = abs(name.hashValue) % palette.count
        let (r, g, b) = palette[index]
        return Color(red: r, green: g, blue: b)
    }
}

#Preview {
    OnboardingSavingStep(
        projectName: "つくろぐ",
        platform: "iOS",
        languages: ["Swift", "TypeScript"],
        onAdvance: {}
    )
}
