import SwiftUI
import PhotosUI

/// Step 12 (2026-04-14): アバター画像選択 (任意)。
struct OnboardingAvatarStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        OnboardingQuestionShell(
            title: "onboarding.project.icon.title",
            subtitle: "onboarding.profileIntro.subtitle",
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
                // PhotosPicker の label は @Sendable closure。main-actor VM property を
                // 直接参照できないので Sendable value (String/Data?) を事前キャプチャ。
                // `some View` 型の local capture も Sendable 違反になるため、View 構築は
                // closure 内でインライン (helper struct 経由)。
                let name = viewModel.displayName
                let handle = viewModel.handleInput
                let data = viewModel.avatarImageData
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    OnboardingAvatarPreviewContent(
                        displayName: name,
                        handle: handle,
                        avatarData: data
                    )
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

}

/// PhotosPicker の @Sendable label closure 内で安全に描画するため、独立した View 構造体
/// として切り出す。init 引数は全て Sendable (String / Data?) のみ。
private struct OnboardingAvatarPreviewContent: View {
    let displayName: String
    let handle: String
    let avatarData: Data?

    var body: some View {
        let gradientColors = [
            OnboardingAccountPromptStep.iconColor(for: displayName.isEmpty ? "You" : displayName),
            OnboardingAccountPromptStep.iconColor(for: handle.isEmpty ? "Handle" : handle).opacity(0.7),
        ]

        ZStack {
            if let avatarData, let uiImage = UIImage(data: avatarData) {
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
