import SwiftUI

/// Step 08: プロフィール設定。
/// 表示名と興味カテゴリを入力して完了。
/// Auth 未実装のため、データはローカル保持のみ。
struct OnboardingProfileSetupStep: View {
    @Binding var displayName: String
    @Binding var selectedInterests: Set<String>
    let interestOptions: [String]
    let onFinish: () -> Void

    @FocusState private var focused: Bool
    @State private var appeared = false
    @State private var gridAppeared = false

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 100)

                Text("あなたについて")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tracking(-0.5)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Spacer().frame(height: 8)

                Text("気になる分野を選んでください")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.clTextSecondary)
                    .opacity(appeared ? 0.8 : 0)

                Spacer().frame(height: 36)

                // Display name
                VStack(alignment: .leading, spacing: 10) {
                    Text("表示名")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)

                    TextField("", text: $displayName, prompt:
                        Text("名前を入力")
                            .foregroundStyle(Color.clTextTertiary.opacity(0.5))
                    )
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
                    .tint(Color.clTextPrimary)
                    .focused($focused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.clSurfaceHigh)
                    )
                }
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)

                Spacer().frame(height: 28)

                // Interest grid
                interestGrid
                    .padding(.horizontal, 32)

                Spacer()

                // Complete
                Button {
                    HapticManager.medium()
                    focused = false
                    onFinish()
                } label: {
                    Text("はじめる")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.clBackground)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Capsule().fill(Color.clTextPrimary))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 32)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

                Spacer().frame(height: 12)

                Button {
                    HapticManager.light()
                    focused = false
                    onFinish()
                } label: {
                    Text("スキップ")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.15)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    gridAppeared = true
                }
            }
        }
    }

    // MARK: - Interest Grid

    private var interestGrid: some View {
        let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]
        return LazyVGrid(columns: columns, spacing: 10) {
            ForEach(Array(interestOptions.enumerated()), id: \.offset) { index, option in
                interestChip(option, index: index)
            }
        }
    }

    private func interestChip(_ interest: String, index: Int) -> some View {
        let selected = selectedInterests.contains(interest)
        return Button {
            HapticManager.selection()
            withAnimation(.spring(duration: 0.35, bounce: 0.25)) {
                if selected {
                    selectedInterests.remove(interest)
                } else {
                    selectedInterests.insert(interest)
                }
            }
        } label: {
            Text(interest)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selected ? Color.clBackground : Color.clTextPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Capsule().fill(selected ? Color.clTextPrimary : Color.clSurfaceHigh)
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
        .opacity(gridAppeared ? 1 : 0)
        .offset(y: gridAppeared ? 0 : 14)
        .animation(
            .spring(duration: 0.6, bounce: 0.2).delay(Double(index) * 0.04),
            value: gridAppeared
        )
    }
}

#Preview {
    OnboardingProfileSetupStep(
        displayName: .constant(""),
        selectedInterests: .constant(["iOS"]),
        interestOptions: OnboardingViewModel.interestOptions,
        onFinish: {}
    )
}
