import SwiftUI
import SwiftData

/// オンボーディング root。
/// Linear 流 hands-on learning + Day One 流 "first entry" を融合した 6 画面フロー。
/// 世界観 (wordmark) は起動時 SplashView (動画ロゴ) が担当するため onboarding 内では省略。
/// すべての step 間遷移は `.onboardingStep` (offset+opacity+blur) で繋がる。
/// step 05 (saving) に入った瞬間に本物の SDTimeEntry を 1 件挿入する。
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
        case .tagline:
            OnboardingTaglineStep(onAdvance: { viewModel.advance() })

        case .projectName:
            OnboardingProjectNameStep(
                projectName: Binding(
                    get: { viewModel.projectName },
                    set: { viewModel.projectName = $0 }
                ),
                canAdvance: viewModel.canAdvanceFromProjectName,
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

        case .tag:
            OnboardingTagStep(
                selectedTag: Binding(
                    get: { viewModel.selectedTag },
                    set: { viewModel.selectedTag = $0 }
                ),
                options: OnboardingViewModel.tagOptions,
                onAdvance: { viewModel.advance() }
            )

        case .saving:
            OnboardingSavingStep(
                projectName: viewModel.savedProjectName.isEmpty ? viewModel.projectName : viewModel.savedProjectName,
                durationMinutes: viewModel.savedDurationMinutes == 0 ? max(1, viewModel.totalMinutes) : viewModel.savedDurationMinutes,
                categoryName: viewModel.savedCategoryName.isEmpty ? (viewModel.selectedTag ?? "開発") : viewModel.savedCategoryName,
                onAdvance: { viewModel.advance() }
            )

        case .welcome:
            OnboardingWelcomeStep(
                projectName: viewModel.savedProjectName,
                durationMinutes: viewModel.savedDurationMinutes,
                categoryName: viewModel.savedCategoryName,
                onFinish: { isPresented = false }
            )
        }
    }
}
