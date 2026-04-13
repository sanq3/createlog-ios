import SwiftUI
import PhotosUI

/// Step 12 (2026-04-14): アバター画像選択 (任意)。
struct OnboardingAvatarStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        OnboardingQuestionShell(
            title: "アイコンを選びましょう",
            subtitle: "あとで変更できます",
            isOptional: true,
            canAdvance: true,
            isSaving: viewModel.isSavingProfile,
            errorMessage: viewModel.profileSaveError,
            onContinue: {
                Task { @MainActor in
                    _ = await viewModel.saveAvatar()
                    onAdvance()
                }
            },
            onSkip: {
                viewModel.avatarImageData = nil
                onAdvance()
            },
            input: {
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    avatarPreview
                }
                .buttonStyle(.plain)
            },
            preview: {
                OnboardingProfilePreviewCard(
                    displayName: viewModel.displayName,
                    handle: viewModel.handleInput,
                    avatarData: viewModel.avatarImageData,
                    bio: viewModel.bio,
                    roleTags: Array(viewModel.roleTags).sorted()
                )
            }
        )
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.avatarImageData = data
                }
            }
        }
    }

    @ViewBuilder
    private var avatarPreview: some View {
        let gradientColors = [
            OnboardingAccountPromptStep.iconColor(for: viewModel.displayName.isEmpty ? "You" : viewModel.displayName),
            OnboardingAccountPromptStep.iconColor(for: viewModel.handleInput.isEmpty ? "Handle" : viewModel.handleInput).opacity(0.7),
        ]

        ZStack {
            if let data = viewModel.avatarImageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "camera.fill")
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
}
