import SwiftUI
import PhotosUI

/// Step 07 (2026-04-14): マイプロダクトの詳細入力。
/// projectName の後に挿入。URL / 説明 / アイコン画像 / リリース状況 を scroll 1 画面で入力。
/// 全項目スキップ可 (アイコンは頭文字フォールバック)。
struct OnboardingProjectDetailStep: View {
    @Bindable var viewModel: OnboardingViewModel
    let onAdvance: () -> Void

    @State private var appeared = false
    @State private var cardVisible = false
    @State private var ctaVisible = false
    @State private var pickerItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case url, github, description }

    var body: some View {
        ZStack {
            Color.clBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    Text("プロダクトの詳細を\n教えてください")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)
                        .tracking(-0.5)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)

                    Spacer().frame(height: 10)

                    Text("あとで設定画面から変更できます")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.5))
                        .opacity(appeared ? 1 : 0)

                    Spacer().frame(height: 32)

                    VStack(spacing: 16) {
                        iconPicker
                        urlField
                        githubField
                        descriptionField
                        statusPicker
                    }
                    .padding(.horizontal, 24)
                    .opacity(cardVisible ? 1 : 0)
                    .offset(y: cardVisible ? 0 : 20)

                    Spacer().frame(height: 40)

                    VStack(spacing: 10) {
                        Button {
                            HapticManager.light()
                            onAdvance()
                        } label: {
                            Text("続ける")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Capsule().fill(Color.clAccent))
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.light()
                            onAdvance()
                        } label: {
                            Text("あとで設定する")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary.opacity(0.45))
                        }
                    }
                    .padding(.horizontal, 32)
                    .opacity(ctaVisible ? 1 : 0)
                    .offset(y: ctaVisible ? 0 : 12)

                    Spacer().frame(height: 40)
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.15).delay(0.1)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.spring(duration: 0.7, bounce: 0.2)) {
                    cardVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.spring(duration: 0.6, bounce: 0.2)) {
                    ctaVisible = true
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { @MainActor in
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    viewModel.iconImageData = data
                }
            }
        }
    }

    // MARK: - Sections

    private var iconPicker: some View {
        PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
            ZStack {
                if let data = viewModel.iconImageData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(iconFallbackColor)
                        .frame(width: 88, height: 88)
                        .overlay(
                            Text(String(viewModel.projectName.prefix(1)))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundStyle(.white.opacity(0.92))
                        )
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "camera.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Circle().fill(Color.clAccent))
                            .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 2))
                            .offset(x: 4, y: 4)
                    }
                }
                .frame(width: 88, height: 88)
            }
        }
        .buttonStyle(.plain)
    }

    private var urlField: some View {
        labeledField(label: "公開 URL (App Store / Play Store / Web)") {
            TextField("https://", text: $viewModel.storeURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .url)
                .onSubmit { focusedField = .github }
        }
    }

    private var githubField: some View {
        labeledField(label: "GitHub URL (任意)") {
            TextField("https://github.com/...", text: $viewModel.githubURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($focusedField, equals: .github)
                .onSubmit { focusedField = .description }
        }
    }

    private var descriptionField: some View {
        labeledField(label: "簡単な説明 (1-2 行)") {
            TextField("何をするプロダクトか", text: $viewModel.appDescription, axis: .vertical)
                .lineLimit(2...4)
                .submitLabel(.done)
                .focused($focusedField, equals: .description)
        }
    }

    private var statusPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("リリース状況")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextPrimary.opacity(0.55))

            HStack(spacing: 8) {
                ForEach(ProjectStatus.allCases, id: \.self) { status in
                    Button {
                        HapticManager.light()
                        viewModel.releaseStatus = status
                    } label: {
                        Text(status.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(
                                viewModel.releaseStatus == status ? .white : Color.clTextPrimary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(
                                        viewModel.releaseStatus == status
                                            ? Color.clAccent
                                            : Color.clSurfaceHigh
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(
                                        viewModel.releaseStatus == status
                                            ? Color.clear
                                            : Color.clTextPrimary.opacity(0.08),
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

    private var iconFallbackColor: Color {
        OnboardingAccountPromptStep.iconColor(for: viewModel.projectName)
    }
}
