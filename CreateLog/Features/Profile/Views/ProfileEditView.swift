import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProfileEditViewModel

    init() {
        _viewModel = State(initialValue: ProfileEditViewModel(user: MockData.currentUser))
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
            .navigationTitle("プロフィールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        HapticManager.light()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(viewModel.canSave ? Color.clAccent : Color.clTextTertiary)
                    .disabled(!viewModel.canSave)
                }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Button {
            // TODO: PhotosPicker表示
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    initials: String(viewModel.displayName.prefix(1)),
                    size: 80,
                    status: .offline
                )

                Image(systemName: "camera.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.clAccent, in: Circle())
                    .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 2))
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 20) {
            fieldContainer(label: "表示名") {
                HStack {
                    TextField("表示名", text: $viewModel.displayName)
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

            fieldContainer(label: "ユーザー名") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("@")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextTertiary)

                        TextField("ユーザー名", text: $viewModel.handle)
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
                        Text("英数字と_のみ、3〜15文字")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.clError)
                    }
                }
            }

            fieldContainer(label: "自己紹介") {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("自己紹介を入力...", text: $viewModel.bio, axis: .vertical)
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

            fieldContainer(label: "職業") {
                TextField("職業", text: $viewModel.occupation)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
            }

            fieldContainer(label: "経験年数") {
                Picker("経験年数", selection: $viewModel.experienceLevel) {
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
            Text("スキル")
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
                TextField("スキルを追加...", text: $viewModel.newSkill)
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
            Text("興味カテゴリ")
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
            Text("外部リンク")
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
                    Text("リンクを追加")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Color.clAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private func fieldContainer<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
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
