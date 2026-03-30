import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var handle: String
    @State private var bio: String
    @State private var occupation: String
    @State private var experienceLevel: ExperienceLevel
    @State private var links: [EditableLink]

    private let originalName: String
    private let originalHandle: String
    private let originalBio: String
    private let originalOccupation: String
    private let originalExperience: ExperienceLevel
    private let originalLinks: [EditableLink]

    private var hasChanges: Bool {
        displayName != originalName
            || handle != originalHandle
            || bio != originalBio
            || occupation != originalOccupation
            || experienceLevel != originalExperience
            || links != originalLinks
    }

    private var isHandleValid: Bool {
        let pattern = /^[a-zA-Z0-9_]{3,15}$/
        return handle.wholeMatch(of: pattern) != nil
    }

    init() {
        let user = MockData.currentUser
        _displayName = State(initialValue: user.name)
        _handle = State(initialValue: user.handle)
        _bio = State(initialValue: user.bio)
        _occupation = State(initialValue: "iOSエンジニア")
        _experienceLevel = State(initialValue: .threeToFive)
        _links = State(initialValue: user.links.map { EditableLink(url: $0.url) })

        originalName = user.name
        originalHandle = user.handle
        originalBio = user.bio
        originalOccupation = "iOSエンジニア"
        originalExperience = .threeToFive
        originalLinks = user.links.map { EditableLink(url: $0.url) }
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
                    .foregroundStyle(hasChanges ? Color.clAccent : Color.clTextTertiary)
                    .disabled(!hasChanges || !isHandleValid)
                }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        Button {
            showPhotoOptions()
        } label: {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(
                    initials: String(displayName.prefix(1)),
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
            // 表示名
            fieldContainer(label: "表示名") {
                HStack {
                    TextField("表示名", text: $displayName)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .onChange(of: displayName) { _, newValue in
                            if newValue.count > 50 {
                                displayName = String(newValue.prefix(50))
                            }
                        }

                    Text("\(50 - displayName.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clTextTertiary)
                        .monospacedDigit()
                }
            }

            // ハンドル
            fieldContainer(label: "ユーザー名") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 0) {
                        Text("@")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextTertiary)

                        TextField("ユーザー名", text: $handle)
                            .font(.system(size: 15))
                            .foregroundStyle(Color.clTextPrimary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onChange(of: handle) { _, newValue in
                                if newValue.count > 15 {
                                    handle = String(newValue.prefix(15))
                                }
                            }
                    }

                    if !handle.isEmpty && !isHandleValid {
                        Text("英数字と_のみ、3〜15文字")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.clError)
                    }
                }
            }

            // 自己紹介
            fieldContainer(label: "自己紹介") {
                VStack(alignment: .trailing, spacing: 4) {
                    TextField("自己紹介を入力...", text: $bio, axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineLimit(4, reservesSpace: true)
                        .onChange(of: bio) { _, newValue in
                            if newValue.count > 150 {
                                bio = String(newValue.prefix(150))
                            }
                        }

                    Text("\(150 - bio.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.clTextTertiary)
                        .monospacedDigit()
                }
            }

            // 職業
            fieldContainer(label: "職業") {
                TextField("職業", text: $occupation)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
            }

            // 経験年数
            fieldContainer(label: "経験年数") {
                Picker("経験年数", selection: $experienceLevel) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.label).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.clTextPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 外部リンク
            VStack(alignment: .leading, spacing: 12) {
                Text("外部リンク")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.clTextSecondary)

                ForEach(links) { link in
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
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                links.removeAll { $0.id == link.id }
                            }
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }

                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        links.append(EditableLink(url: ""))
                    }
                    HapticManager.light()
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
            get: { links.first { $0.id == id }?.url ?? "" },
            set: { newValue in
                if let index = links.firstIndex(where: { $0.id == id }) {
                    links[index] = EditableLink(id: id, url: newValue)
                }
            }
        )
    }

    private func showPhotoOptions() {
        print("[ProfileEdit] Photo picker action sheet would appear here")
        print("  - ライブラリから選択")
        print("  - カメラで撮影")
        print("  - キャンセル")
    }
}

// MARK: - Supporting Types

private struct EditableLink: Identifiable, Equatable {
    let id: UUID
    let url: String

    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }
}

private enum ExperienceLevel: String, CaseIterable {
    case lessThanOne
    case oneToThree
    case threeToFive
    case fiveToTen
    case moreThanTen

    var label: String {
        switch self {
        case .lessThanOne: return "1年未満"
        case .oneToThree: return "1-3年"
        case .threeToFive: return "3-5年"
        case .fiveToTen: return "5-10年"
        case .moreThanTen: return "10年以上"
        }
    }
}
