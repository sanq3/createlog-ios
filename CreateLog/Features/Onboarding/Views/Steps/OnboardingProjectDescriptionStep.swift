import SwiftUI

/// Step 18 (2026-04-14): プロダクトの説明文 (任意)。
struct OnboardingProjectDescriptionStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingQuestionShell(
            title: "どんなプロダクトですか?",
            subtitle: "1-2 行で簡潔に",
            isOptional: true,
            canAdvance: true,
            isSaving: false,
            errorMessage: nil,
            onContinue: {
                viewModel.saveProjectDescription()
                onAdvance()
            },
            onSkip: {
                viewModel.appDescription = ""
                onAdvance()
            },
            input: {
                OnboardingLabeledInput(label: nil) {
                    TextField("onboarding.project.desc.placeholder", text: $viewModel.appDescription, axis: .vertical)
                        .lineLimit(3...5)
                        .submitLabel(.done)
                        .focused($focused)
                }
            },
            preview: {
                OnboardingProductPreviewCard(
                    projectName: viewModel.savedProjectName,
                    platform: viewModel.savedPlatforms.joined(separator: " / "),
                    iconData: viewModel.iconImageData,
                    storeURL: viewModel.storeURL,
                    githubURL: viewModel.githubURL,
                    appDescription: viewModel.appDescription,
                    status: nil
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
