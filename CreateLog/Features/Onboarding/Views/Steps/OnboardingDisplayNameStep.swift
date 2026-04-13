import SwiftUI

/// Step 10 (2026-04-14): 表示名入力 (必須)。
/// 下部 ProfilePreviewCard が入力に連動して即座に更新される。
struct OnboardingDisplayNameStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingQuestionShell(
            title: "あなたの名前は?",
            subtitle: "プロフィールに表示されます",
            isOptional: false,
            canAdvance: canAdvance,
            isSaving: viewModel.isSavingProfile,
            errorMessage: viewModel.profileSaveError,
            onContinue: {
                Task { @MainActor in
                    if await viewModel.saveDisplayName() {
                        onAdvance()
                    }
                }
            },
            onSkip: nil,
            input: {
                OnboardingLabeledInput(label: nil) {
                    TextField("例: つくろぐ太郎", text: $viewModel.displayName)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($focused)
                        .onSubmit {
                            if canAdvance {
                                Task { @MainActor in
                                    if await viewModel.saveDisplayName() {
                                        onAdvance()
                                    }
                                }
                            }
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
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                focused = true
            }
        }
    }

    private var canAdvance: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
