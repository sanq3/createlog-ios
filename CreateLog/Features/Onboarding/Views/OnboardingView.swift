import SwiftUI
import SwiftData

/// オンボーディング root。13 画面フロー (マイプロダクト + プロフィール + ハンドル):
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName →
/// projectDetail → saving → accountPrompt → signInCelebration → profileSetup →
/// handleSetup → completionCelebration
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
            OnboardingWelcomeHeroStep(
                onAdvance: { viewModel.advance() },
                onLogin: { viewModel.jumpToAccountPrompt() }
            )

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

        case .projectDetail:
            OnboardingProjectDetailStep(
                viewModel: viewModel,
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
                isLoginMode: viewModel.isLoginMode,
                authViewModel: authViewModel,
                onAdvance: { viewModel.advance() },
                onBackToWelcome: { viewModel.backToWelcome() }
            )

        case .signInCelebration:
            OnboardingSignInCelebrationStep(onAdvance: { viewModel.advance() })

        case .profileSetup:
            OnboardingProfileSetupStep(
                viewModel: viewModel,
                onAdvance: { viewModel.advance() }
            )

        case .handleSetup:
            OnboardingHandleStep(
                viewModel: viewModel,
                onComplete: { viewModel.advance() },
                onSkip: { viewModel.advance() }
            )

        case .completionCelebration:
            OnboardingCompletionCelebrationStep(onComplete: { isPresented = false })
        }
    }
}
