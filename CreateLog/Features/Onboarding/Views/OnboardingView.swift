import SwiftUI
import SwiftData

/// オンボーディング root。20 画面フロー (2026-04-14 再設計、1 画面 1 質問粒度)。
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName →
/// saving → accountPrompt → signInCelebration → displayName → handleSetup →
/// avatar → bio → roleTag → projectIcon → projectURL → projectGitHub →
/// projectDescription → projectStatus → completionCelebration
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
                    profileRepository: dependencies.profileRepository,
                    appRepository: dependencies.appRepository,
                    authService: dependencies.authService
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
        .overlay(alignment: .topLeading) {
            // 左上 chevron で戻る。戻れる step は ViewModel.canGoBack が判定。
            // 薄く控えめに出すことで「気に入っているミニマルな見た目」を損なわない。
            if viewModel.canGoBack {
                Button {
                    HapticManager.light()
                    viewModel.goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
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

        case .displayName:
            OnboardingDisplayNameStep(
                viewModel: viewModel,
                onAdvance: { viewModel.advance() }
            )

        case .handleSetup:
            OnboardingHandleStep(
                viewModel: viewModel,
                onComplete: { viewModel.advance() }
            )

        case .avatar:
            OnboardingAvatarStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .bio:
            OnboardingBioStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .roleTag:
            OnboardingRoleTagStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .projectIcon:
            OnboardingProjectIconStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .projectURL:
            OnboardingProjectURLStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .projectGitHub:
            OnboardingProjectGitHubStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .projectDescription:
            OnboardingProjectDescriptionStep(viewModel: viewModel, onAdvance: { viewModel.advance() })

        case .projectStatus:
            OnboardingProjectStatusStep(viewModel: viewModel, onAdvance: {
                // projectStatus を抜けた瞬間 = SDProject の全フィールド確定。
                // completionCelebration の演出 (1.7s) と並走で remote sync を kick。
                // 失敗してもローカル SDProject は残るので UI ブロックしない。
                Task { await viewModel.syncProjectToRemote() }
                viewModel.advance()
            })

        case .completionCelebration:
            OnboardingCompletionCelebrationStep(onComplete: { isPresented = false })
        }
    }
}
