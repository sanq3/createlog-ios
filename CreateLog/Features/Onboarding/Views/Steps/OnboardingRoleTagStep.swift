import SwiftUI

/// Step 14 (2026-04-14): 役割 / スキルタグ選択 (任意、複数選択可)。
/// 保存は先頭 1 個を `profiles.occupation` に入れる。
struct OnboardingRoleTagStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    private static let availableRoles = [
        "iOS 開発", "Android 開発", "Web 開発", "バックエンド",
        "デザイン", "個人開発", "スタートアップ", "学生",
    ]

    var body: some View {
        OnboardingQuestionShell(
            title: "何をしている人ですか?",
            subtitle: "複数選択できます",
            isOptional: true,
            canAdvance: true,
            isSaving: viewModel.isSavingProfile,
            errorMessage: viewModel.profileSaveError,
            onContinue: {
                Task { @MainActor in
                    _ = await viewModel.saveRoleTag()
                    onAdvance()
                }
            },
            onSkip: {
                viewModel.roleTags = []
                onAdvance()
            },
            input: {
                FlowLayout(spacing: 8) {
                    ForEach(Self.availableRoles, id: \.self) { role in
                        let selected = viewModel.roleTags.contains(role)
                        Button {
                            HapticManager.light()
                            if selected {
                                viewModel.roleTags.remove(role)
                            } else {
                                viewModel.roleTags.insert(role)
                            }
                        } label: {
                            Text(role)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(selected ? .white : Color.clTextPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule()
                                        .fill(selected ? Color.clAccent : Color.clSurfaceHigh)
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
                    }
                }
            },
            preview: {
                OnboardingProfilePreviewCard(
                    displayName: viewModel.displayName,
                    handle: viewModel.handleInput,
                    avatarData: viewModel.avatarImageData,
                    bio: viewModel.bio,
                    roleTags: Array(viewModel.roleTags).sorted()
                )
            }
        )
    }
}
