import SwiftUI

/// Step 19 (2026-04-14): プロダクトのリリース状況 (任意)。
struct OnboardingProjectStatusStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    var body: some View {
        OnboardingQuestionShell(
            title: "今のリリース状況は?",
            subtitle: "プロフィールにバッジで表示されます",
            isOptional: true,
            canAdvance: true,
            isSaving: false,
            errorMessage: nil,
            onContinue: {
                viewModel.saveProjectStatus()
                onAdvance()
            },
            onSkip: {
                viewModel.releaseStatus = .draft
                onAdvance()
            },
            input: {
                VStack(spacing: 10) {
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Button {
                            HapticManager.light()
                            viewModel.releaseStatus = status
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: viewModel.releaseStatus == status ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(viewModel.releaseStatus == status ? Color.clAccent : Color.clTextPrimary.opacity(0.3))

                                Text(status.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(Color.clTextPrimary)

                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color.clSurfaceHigh)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        viewModel.releaseStatus == status ? Color.clAccent.opacity(0.5) : Color.clTextPrimary.opacity(0.06),
                                        lineWidth: viewModel.releaseStatus == status ? 1.5 : 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
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
                    status: viewModel.releaseStatus
                )
            }
        )
    }
}
