import SwiftUI
import SwiftData

/// オンボーディング root。8 画面フロー:
/// welcome → appShowcase → tag → duration → projectName → saving → accountPrompt → profileSetup
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext

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
                viewModel = OnboardingViewModel(modelContext: modelContext)
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

        case .tag:
            OnboardingTagStep(
                selectedTag: Binding(
                    get: { viewModel.selectedTag },
                    set: { viewModel.selectedTag = $0 }
                ),
                options: OnboardingViewModel.tagOptions,
                onAdvance: { viewModel.advance() }
            )

        case .duration:
            OnboardingDurationStep(
                hours: Binding(
                    get: { viewModel.durationHours },
                    set: { viewModel.durationHours = $0 }
                ),
                minutes: Binding(
                    get: { viewModel.durationMinutes },
                    set: { viewModel.durationMinutes = $0 }
                ),
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
                durationMinutes: viewModel.savedDurationMinutes == 0 ? max(1, viewModel.totalMinutes) : viewModel.savedDurationMinutes,
                categoryName: viewModel.savedCategoryName.isEmpty ? (viewModel.selectedTag ?? "開発") : viewModel.savedCategoryName,
                onAdvance: { viewModel.advance() }
            )

        case .accountPrompt:
            OnboardingAccountPromptStep(
                projectName: viewModel.savedProjectName,
                durationMinutes: viewModel.savedDurationMinutes,
                categoryName: viewModel.savedCategoryName,
                onAdvance: { viewModel.advance() },
                onSkip: { isPresented = false }
            )

        case .profileSetup:
            OnboardingProfileSetupStep(
                displayName: Binding(
                    get: { viewModel.displayName },
                    set: { viewModel.displayName = $0 }
                ),
                selectedInterests: Binding(
                    get: { viewModel.selectedInterests },
                    set: { viewModel.selectedInterests = $0 }
                ),
                interestOptions: OnboardingViewModel.interestOptions,
                onFinish: { isPresented = false }
            )
        }
    }
}
