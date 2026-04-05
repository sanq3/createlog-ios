import SwiftUI

/// Step 06: 保存演出。
/// エントリ時点で performSave() が呼ばれ、実際に SwiftData に 1 件挿入される。
/// 演出: 「保存中...」 → 0.8 秒後 → 「保存した」にクロスフェード。
/// さらに 0.3 秒後、作成された記録カードが下から scale 0.9 + blur 10 → 1.0 + blur 0 で浮上。
/// その 1.1 秒後に「続ける」ボタンが浮上。
struct OnboardingSavingStep: View {
    let projectName: String
    let durationMinutes: Int
    let categoryName: String
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

                // 状態テキスト (保存中 ⇄ 保存した)
                ZStack {
                    Text("保存中")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.clTextTertiary)
                        .opacity(showSaving && !savedText ? 1 : 0)
                        .blur(radius: savedText ? 6 : 0)

                    Text("保存した")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .opacity(savedText ? 1 : 0)
                        .scaleEffect(savedText ? 1 : 0.92)
                }
                .tracking(-0.5)

                // 作成された記録カード
                savedCard
                    .opacity(cardVisible ? 1 : 0)
                    .scaleEffect(cardVisible ? 1 : 0.9)
                    .blur(radius: cardVisible ? 0 : 10)

                Spacer()

                Button {
                    HapticManager.light()
                    onAdvance()
                } label: {
                    Text("続ける")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clBackground)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 16)
                        .background(
                            Capsule().fill(Color.clTextPrimary)
                        )
                }
                .buttonStyle(.plain)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 20)
                .blur(radius: ctaVisible ? 0 : 4)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            // 保存中 text 出現
            withAnimation(.spring(duration: 0.5, bounce: 0.15).delay(0.1)) {
                showSaving = true
            }
            // 0.9 秒後に 保存した にクロスフェード + haptic success
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                HapticManager.success()
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    savedText = true
                }
            }
            // 1.25 秒後にカード浮上
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                withAnimation(.spring(duration: 0.8, bounce: 0.22)) {
                    cardVisible = true
                }
            }
            // 2.3 秒後に CTA 浮上
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                withAnimation(.spring(duration: 0.55, bounce: 0.25)) {
                    ctaVisible = true
                }
            }
        }
    }

    private var savedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(categoryName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.clTextTertiary)
                .tracking(1.5)
                .textCase(.uppercase)

            Text(projectName)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                Text(DurationFormatter.format(minutes: durationMinutes))
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(Color.clTextPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 32)
    }
}

#Preview {
    OnboardingSavingStep(
        projectName: "つくろぐ iOS",
        durationMinutes: 90,
        categoryName: "開発",
        onAdvance: {}
    )
}
