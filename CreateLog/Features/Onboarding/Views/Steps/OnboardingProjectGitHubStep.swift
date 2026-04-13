import SwiftUI

/// Step 17 (2026-04-14): GitHub URL (任意)。
struct OnboardingProjectGitHubStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        OnboardingQuestionShell(
            title: "GitHub リポジトリは?",
            subtitle: "OSS なら公開しておくと反応がもらえます",
            isOptional: true,
            canAdvance: true,
            isSaving: false,
            errorMessage: nil,
            onContinue: {
                viewModel.saveProjectGitHub()
                onAdvance()
            },
            onSkip: {
                viewModel.githubURL = ""
                onAdvance()
            },
            input: {
                OnboardingLabeledInput(label: nil) {
                    TextField("https://github.com/...", text: $viewModel.githubURL)
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
