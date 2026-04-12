import SwiftUI
import SwiftData

/// オンボーディング root。9 画面フロー (マイプロダクト登録 + ハンドル選択):
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName → saving → accountPrompt → handleSetup
struct OnboardingView: View {
    @Binding var isPresented: Bool
    var authViewModel: AuthViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dependencies) private var dependencies

    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            if let viewModel {
                content(for: viewModel)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = OnboardingViewModel(
                    modelContext: modelContext,
                    profileRepository: dependencies.profileRepository
                )
            }
        }
    }

    @ViewBuilder
    private func content(for viewModel: OnboardingViewModel) -> some View {
        ZStack {
            currentStepView(viewModel)
                .id(viewModel.currentStep.rawValue)
                .transition(.onboardingStep)
        }
        .animation(.spring(duration: 0.55, bounce: 0.1), value: viewModel.currentStep)
        .onChange(of: viewModel.currentStep) { _, newStep in
            if newStep == .saving {
                viewModel.performSave()
            }
        }
    }

    @ViewBuilder
    private func currentStepView(_ viewModel: OnboardingViewModel) -> some View {
        switch viewModel.currentStep {
        case .welcome:
            OnboardingWelcomeHeroStep(onAdvance: { viewModel.advance() })

        case .appShowcase:
            OnboardingAppShowcaseStep(onAdvance: { viewModel.advance() })

        case .tutorialIntro:
            OnboardingTutorialIntroStep(onAdvance: { viewModel.advance() })

        case .platform:
            OnboardingPlatformStep(
                selectedPlatforms: Binding(
                    get: { viewModel.selectedPlatforms },
                    set: { viewModel.selectedPlatforms = $0 }
                ),
                onAdvance: { viewModel.advance() }
            )

        case .techStack:
            OnboardingTechStackStep(
                selectedStack: Binding(
                    get: { viewModel.selectedTechStack },
                    set: { viewModel.selectedTechStack = $0 }
                ),
                selectedPlatforms: viewModel.selectedPlatforms,
                onAdvance: { viewModel.advance() }
            )

        case .projectName:
            OnboardingProjectNameStep(
                projectName: Binding(
                    get: { viewModel.projectName },
                    set: { viewModel.projectName = $0 }
                ),
                canAdvance: viewModel.canAdvanceFromProjectName,
                onAdvance: { viewModel.advance() }
            )

        case .saving:
            OnboardingSavingStep(
                projectName: viewModel.savedProjectName.isEmpty ? viewModel.projectName : viewModel.savedProjectName,
                platform: viewModel.savedPlatforms.isEmpty
                    ? viewModel.selectedPlatforms.joined(separator: " / ")
                    : viewModel.savedPlatforms.joined(separator: " / "),
                languages: Array(viewModel.selectedTechStack),
                onAdvance: { viewModel.advance() }
            )

        case .accountPrompt:
            OnboardingAccountPromptStep(
                projectName: viewModel.savedProjectName,
                platform: viewModel.savedPlatforms.joined(separator: " / "),
                authViewModel: authViewModel,
                onAdvance: { viewModel.advance() },
                onSkip: { isPresented = false }
            )

        case .handleSetup:
            OnboardingHandleStep(
                viewModel: viewModel,
                onComplete: { isPresented = false },
                onSkip: { isPresented = false }
            )
        }
    }
}
