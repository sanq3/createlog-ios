import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileEditViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?

    init(user: User, profileRepository: any ProfileRepositoryProtocol) {
        _viewModel = State(initialValue: ProfileEditViewModel(
            user: user,
            profileRepository: profileRepository
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    avatarSection
                    formSection
                }
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            .background(Color.clBackground)
            .navigationTitle("profile.edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextPrimary)
                    .disabled(viewModel.isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        HapticManager.light()
                        Task { await viewModel.save() }
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canSave ? Color.clAccent : Color.clTextTertiary)
                    .disabled(!viewModel.canSave)
                }
            }
            .errorBanner($viewModel.errorMessage)
            .onChange(of: viewModel.didSaveSuccessfully) { _, saved in
                if saved { dismiss() }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        PhotosPicker(
            selection: $selectedPhoto,
            matching: .images,
            photoLibrary: .shared()
        ) {
            ZStack(alignment: .bottomTrailing) {
                if let avatarImage {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    AvatarView(
                        initials: String(viewModel.displayName.prefix(1)),
                        size: 80,
                        status: .offline,
                        imageURL: viewModel.currentAvatarUrl.flatMap(URL.init(string:))
                    )
                }

                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.clAccent, in: Circle())
                    .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 2))
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedPhoto) { _, newItem in
            Task { await loadAvatar(newItem) }
        }
    }

    /// 選択された画像を読み込んで画面に表示 + ViewModel にバイナリを渡す。
    /// 実際の Supabase Storage へのアップロードは viewModel.save() 時に行う。
    private func loadAvatar(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        guard let uiImage = UIImage(data: data) else { return }
        avatarImage = Image(uiImage: uiImage)
        viewModel.pendingAvatarData = data
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {
            fieldContainer(label: "profile.displayName") {
                HStack {
                    TextField("profile.displayName", text: $viewModel.displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .onChange(of: viewModel.displayName) { _, newValue in
                            if newValue.count > 50 {
                                viewModel.displayName = String(newValue.prefix(50))
                            }
                        }

                    Text("\(50 - viewModel.displayName.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clTextTertiary)
                        .monospacedDigit()
                }
            }

            fieldContainer(label: "profile.handle") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("@")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextTertiary)

                        TextField("profile.handle", text: $viewModel.handle)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: viewModel.handle) { _, newValue in
                                if newValue.count > 15 {
                                    viewModel.handle = String(newValue.prefix(15))
                                }
                            }
                    }

                    if !viewModel.handle.isEmpty && !viewModel.isHandleValid {
                        Text("auth.handle.rule")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.clError)
                    }
                }
            }

            fieldContainer(label: "profile.bio.label") {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("profile.bio.placeholder", text: $viewModel.bio, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineLimit(4, reservesSpace: true)
                        .onChange(of: viewModel.bio) { _, newValue in
                            if newValue.count > 150 {
                                viewModel.bio = String(newValue.prefix(150))
                            }
                        }

                    Text("\(150 - viewModel.bio.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clTextTertiary)
                        .monospacedDigit()
                }
            }

            fieldContainer(label: "profile.occupation") {
                TextField("profile.occupation", text: $viewModel.occupation)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
            }

            fieldContainer(label: "profile.experience") {
                Picker("profile.experience", selection: $viewModel.experienceLevel) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.clTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            skillsEditSection
            interestsEditSection
            linksEditSection
        }
    }

    // MARK: - Skills Edit

    private var skillsEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.skills")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextSecondary)

            if !viewModel.skills.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(viewModel.skills, id: \.self) { skill in
                        HStack(spacing: 4) {
                            Text(skill)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.clTextPrimary)

                            Button {
                                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                    viewModel.removeSkill(skill)
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.clTextTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.clSurfaceLow, in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.clBorder, lineWidth: 1))
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("profile.skills.add", text: $viewModel.newSkill)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            viewModel.addSkill()
                        }
                    }

                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        viewModel.addSkill()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.newSkill.isEmpty ? Color.clTextTertiary : Color.clAccent)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newSkill.isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Interests Edit

    private var interestsEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.interests")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextSecondary)

            FlowLayout(spacing: 6) {
                ForEach(ProfileEditViewModel.interestOptions, id: \.self) { interest in
                    interestChip(interest)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Links Edit

    private var linksEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.links")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextSecondary)

            ForEach(viewModel.links) { link in
                HStack(spacing: 10) {
                    Image(systemName: "link")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.clTextTertiary)

                    TextField("https://...", text: linkBinding(for: link.id))
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)

                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            viewModel.removeLink(link)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
            }

            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    viewModel.addLink()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("profile.links.add")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.clAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func fieldContainer<Content: View>(label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextSecondary)

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
    }

    private func linkBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { viewModel.links.first { $0.id == id }?.url ?? "" },
            set: { newValue in
                if let index = viewModel.links.firstIndex(where: { $0.id == id }) {
                    viewModel.links[index] = EditableLink(id: id, url: newValue)
                }
            }
        )
    }

    private func interestChip(_ interest: String) -> some View {
        let isSelected = viewModel.interests.contains(interest)
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                viewModel.toggleInterest(interest)
            }
        } label: {
            Text(interest)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? .white : Color.clTextPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.clAccent : Color.clSurfaceLow,
                    in: Capsule()
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Color.clBorder,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
