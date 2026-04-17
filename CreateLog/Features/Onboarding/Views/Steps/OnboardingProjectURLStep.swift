import SwiftUI

/// Step 16 (2026-04-14): プロダクト公開 URL (任意)。
struct OnboardingProjectURLStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingQuestionShell(
            title: "onboarding.project.url.title",
            subtitle: "onboarding.project.url.subtitle",
            isOptional: true,
            canAdvance: true,
            isSaving: false,
            errorMessage: nil,
            onContinue: {
                viewModel.saveProjectURL()
                onAdvance()
            },
            onSkip: {
                viewModel.storeURL = ""
                onAdvance()
            },
            input: {
                OnboardingLabeledInput(label: nil) {
                    TextField("https://", text: $viewModel.storeURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
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
