import SwiftUI

/// Step 05: どんな作業だった？ タグ選択 (ラジオ形式)。
/// 7 個の候補を 2 列 flow で配置。記号ゼロ、テキストと shape のみ。
/// 選択時: 背景反転 (clTextPrimary bg + clBackground text) + haptic selection。
/// 未選択でも「続ける」は有効 (デフォルト=開発で保存)。
struct OnboardingTagStep: View {
    @Binding var selectedTag: String?
    let options: [String]
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var chipsAppeared = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 120)

                Text("どんな作業だった？")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 44)

                tagGrid
                    .padding(.horizontal, 32)

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
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            // staggered chip appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    chipsAppeared = true
                }
            }
        }
    }

    private var tagGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                tagChip(option, index: index)
            }
        }
    }

    private func tagChip(_ tag: String, index: Int) -> some View {
        let selected = selectedTag == tag
        return Button {
            HapticManager.selection()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                selectedTag = selected ? nil : tag
            }
        } label: {
            Text(tag)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(selected ? Color.clBackground : Color.clTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            selected ? Color.clear : Color.clTextPrimary.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .opacity(chipsAppeared ? 1 : 0)
        .offset(y: chipsAppeared ? 0 : 14)
        .animation(
            .spring(duration: 0.6, bounce: 0.2).delay(Double(index) * 0.04),
            value: chipsAppeared
        )
    }
}

#Preview {
    OnboardingTagStep(
        selectedTag: .constant("開発"),
        options: OnboardingViewModel.tagOptions,
        onAdvance: {}
    )
}
