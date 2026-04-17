import SwiftUI

/// Step 14 (2026-04-14): 役割 / スキルタグ選択 (任意、複数選択可)。
/// 保存は先頭 1 個を `profiles.occupation` に入れる。
struct OnboardingRoleTagStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    private static let availableRoles = [
        "onboarding.platform.ios", "onboarding.platform.android",
        "onboarding.platform.web", "onboarding.platform.backend",
        "onboarding.role.design", "onboarding.role.soloDev",
        "onboarding.role.startup", "onboarding.role.student",
    ]

    var body: some View {
        OnboardingQuestionShell(
            title: "onboarding.role.title",
            subtitle: "onboarding.tech.subtitle",
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
                            Text(LocalizedStringKey(role))
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
