import SwiftUI
import PhotosUI

/// Step 15 (2026-04-14): プロダクトアイコン画像 (任意)。
struct OnboardingProjectIconStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        OnboardingQuestionShell(
            title: "プロダクトのアイコン",
            subtitle: "あとで変更できます",
            isOptional: true,
            canAdvance: true,
            isSaving: false,
            errorMessage: nil,
            onContinue: {
                viewModel.saveProjectIcon()
                onAdvance()
            },
            onSkip: {
                viewModel.iconImageData = nil
                onAdvance()
            },
            input: {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    iconPreview
                }
                .buttonStyle(.plain)
            },
            preview: {
                productPreview
            }
        )
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.iconImageData = data
                }
            }
        }
    }

    @ViewBuilder
    private var iconPreview: some View {
        ZStack {
            if let data = viewModel.iconImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(OnboardingAccountPromptStep.iconColor(for: viewModel.projectName.isEmpty ? "Project" : viewModel.projectName))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "photo.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    )
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.clAccent))
                        .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 3))
                }
            }
            .frame(width: 120, height: 120)
        }
        .frame(maxWidth: .infinity)
    }

    private var productPreview: some View {
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
}
