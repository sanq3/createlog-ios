import SwiftUI

/// Step 13 (2026-04-14): 自己紹介 bio 入力 (任意)。
struct OnboardingBioStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingQuestionShell(
            title: "onboarding.bio.title",
            subtitle: "onboarding.platform.subtitle",
            isOptional: true,
            canAdvance: true,
            isSaving: viewModel.isSavingProfile,
            errorMessage: viewModel.profileSaveError,
            onContinue: {
                Task { @MainActor in
                    _ = await viewModel.saveBio()
                    onAdvance()
                }
            },
            onSkip: {
                viewModel.bio = ""
                onAdvance()
            },
            input: {
                OnboardingLabeledInput(label: nil) {
                    TextField("onboarding.bio.placeholder", text: $viewModel.bio, axis: .vertical)
                        .lineLimit(3...5)
                        .submitLabel(.done)
                        .focused($focused)
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focused = true
            }
        }
    }
}
