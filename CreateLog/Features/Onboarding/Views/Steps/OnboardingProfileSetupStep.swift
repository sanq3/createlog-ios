import SwiftUI
import PhotosUI

/// Step 11 (2026-04-14): プロフィール入力。
/// signInCelebration の後に挿入。アバター + 表示名 + bio + 役割タグを scroll 1 画面で入力。
/// 表示名は任意 (空でスキップ可)。役割タグは複数選択可能だが保存は先頭 1 個を occupation に格納。
struct OnboardingProfileSetupStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case displayName, bio }

    private static let availableRoles = [
        "iOS 開発", "Android 開発", "Web 開発", "バックエンド",
        "デザイン", "個人開発", "スタートアップ", "学生",
    ]

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)

                    Text("プロフィールを\n設定しましょう")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Spacer().frame(height: 28)

                    avatarPicker
                        .opacity(cardVisible ? 1 : 0)
                        .scaleEffect(cardVisible ? 1 : 0.9)

                    Spacer().frame(height: 28)

                    VStack(spacing: 16) {
                        displayNameField
                        bioField
                        roleTagSection
                    }
                    .padding(.horizontal, 24)
                    .opacity(cardVisible ? 1 : 0)
                    .offset(y: cardVisible ? 0 : 20)

                    Spacer().frame(height: 16)

                    if let error = viewModel.profileSaveError {
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.clError)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 8)
                    }

                    VStack(spacing: 10) {
                        Button {
                            Task { @MainActor in
                                let success = await viewModel.saveProfileDetails()
                                if success {
                                    HapticManager.light()
                                    onAdvance()
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isSavingProfile {
                                    ProgressView().tint(.white).scaleEffect(0.9)
                                }
                                Text(viewModel.isSavingProfile ? "保存中..." : "続ける")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(Color.clAccent))
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSavingProfile)

                        Button {
                            HapticManager.light()
                            onAdvance()
                        } label: {
                            Text("あとで設定する")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary.opacity(0.45))
                        }
                        .disabled(viewModel.isSavingProfile)
                    }
                    .padding(.horizontal, 32)
                    .opacity(ctaVisible ? 1 : 0)
                    .offset(y: ctaVisible ? 0 : 12)

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear(perform: animateIn)
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.avatarImageData = data
                }
            }
        }
    }

    private func animateIn() {
        let delayFactor: Double = reduceMotion ? 0 : 1
        withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.1 * delayFactor)) {
            appeared = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 * delayFactor) {
            withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                cardVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55 * delayFactor) {
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                ctaVisible = true
            }
        }
    }

    // MARK: - Sections

    private var avatarPicker: some View {
        let nameSource = viewModel.displayName.isEmpty ? viewModel.projectName : viewModel.displayName
        let primaryColor = OnboardingAccountPromptStep.iconColor(for: nameSource)
        let secondaryColor = OnboardingAccountPromptStep.iconColor(for: viewModel.projectName).opacity(0.7)

        return PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let data = viewModel.avatarImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [primaryColor, secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 110, height: 110)
                        .overlay(
                            Text(avatarFallbackInitial)
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        )
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(7)
                            .background(Circle().fill(Color.clAccent))
                            .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 2))
                            .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 110, height: 110)
            }
        }
        .buttonStyle(.plain)
    }

    private var displayNameField: some View {
        labeledField(label: "表示名") {
            TextField("つくろぐ太郎", text: $viewModel.displayName)
                .submitLabel(.next)
                .focused($focusedField, equals: .displayName)
                .onSubmit { focusedField = .bio }
        }
    }

    private var bioField: some View {
        labeledField(label: "自己紹介 (任意)") {
            TextField("どんな開発をしていますか", text: $viewModel.bio, axis: .vertical)
                .lineLimit(2...5)
                .submitLabel(.done)
                .focused($focusedField, equals: .bio)
        }
    }

    private var roleTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("役割 / スキル (任意、複数選択可)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextPrimary.opacity(0.55))

            FlowLayout(spacing: 8) {
                ForEach(Self.availableRoles, id: \.self) { role in
                    let selected = viewModel.roleTags.contains(role)
                    Button {
                        HapticManager.light()
                        if selected {
                            viewModel.roleTags.remove(role)
                        } else {
                            viewModel.roleTags.insert(role)
                        }
                    } label: {
                        Text(role)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(selected ? .white : Color.clTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selected ? Color.clAccent : Color.clSurfaceHigh)
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        selected ? Color.clear : Color.clTextPrimary.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func labeledField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextPrimary.opacity(0.55))
            content()
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(Color.clTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.clSurfaceHigh)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private var avatarFallbackInitial: String {
        let source = viewModel.displayName.trimmingCharacters(in: .whitespaces)
        if !source.isEmpty { return String(source.prefix(1)) }
        return String(viewModel.projectName.prefix(1))
    }
}
