import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var displayName: String
    @State private var handle: String
    @State private var bio: String
    @State private var occupation: String
    @State private var experienceLevel: ExperienceLevel
    @State private var links: [EditableLink]
    @State private var skills: [String]
    @State private var newSkill: String = ""
    @State private var interests: Set<String>

    private let originalName: String
    private let originalHandle: String
    private let originalBio: String
    private let originalOccupation: String
    private let originalExperience: ExperienceLevel
    private let originalLinks: [EditableLink]
    private let originalSkills: [String]
    private let originalInterests: Set<String>

    private static let interestOptions = [
        "iOS", "Android", "Web", "バックエンド", "インフラ",
        "AI/ML", "ゲーム", "デザイン", "個人開発", "OSS",
        "セキュリティ", "データ", "モバイル", "クラウド", "DevOps",
    ]

    private var hasChanges: Bool {
        displayName != originalName
            || handle != originalHandle
            || bio != originalBio
            || occupation != originalOccupation
            || experienceLevel != originalExperience
            || links != originalLinks
            || skills != originalSkills
            || interests != originalInterests
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
        _occupation = State(initialValue: user.occupation)
        _experienceLevel = State(initialValue: user.experienceLevel)
        _links = State(initialValue: user.links.map { EditableLink(url: $0.url) })
        _skills = State(initialValue: user.skills)
        _interests = State(initialValue: Set(user.interests))

        originalName = user.name
        originalHandle = user.handle
        originalBio = user.bio
        originalOccupation = user.occupation
        originalExperience = user.experienceLevel
        originalLinks = user.links.map { EditableLink(url: $0.url) }
        originalSkills = user.skills
        originalInterests = Set(user.interests)
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

            // スキル
            skillsEditSection

            // 興味カテゴリ
            interestsEditSection

            // 外部リンク
            linksEditSection
        }
    }

    // MARK: - Skills Edit

    private var skillsEditSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("スキル")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.clTextSecondary)

            // 既存スキル
            if !skills.isEmpty {
                WrappingChips(items: skills) { skill in
                    HStack(spacing: 4) {
                        Text(skill)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.clTextPrimary)

                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                skills.removeAll { $0 == skill }
                            }
                            HapticManager.light()
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

            // 新規追加
            HStack(spacing: 8) {
                TextField("スキルを追加...", text: $newSkill)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit { addSkill() }

                Button {
                    addSkill()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(newSkill.isEmpty ? Color.clTextTertiary : Color.clAccent)
                }
                .buttonStyle(.plain)
                .disabled(newSkill.isEmpty)
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

            WrappingChips(items: Self.interestOptions) { interest in
                interestChip(interest)
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

                    Button {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            links.removeAll { $0.id == link.id }
                        }
                        HapticManager.light()
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

    private func interestChip(_ interest: String) -> some View {
        let isSelected = interests.contains(interest)
        return Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                if isSelected {
                    interests.remove(interest)
                } else {
                    interests.insert(interest)
                }
            }
            HapticManager.light()
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

    private func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !skills.contains(trimmed) else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            skills.append(trimmed)
        }
        newSkill = ""
        HapticManager.light()
    }

    private func showPhotoOptions() {
        print("[ProfileEdit] Photo picker action sheet would appear here")
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

// MARK: - Wrapping Chips (reusable flow layout for edit screens)

struct WrappingChips<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(items, id: \.self) { item in
                content(item)
                    .padding(.trailing, 6)
                    .padding(.bottom, 6)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= dimension.height + 6
                        }
                        let result = width
                        if item == items.last {
                            width = 0
                        } else {
                            width -= dimension.width + 6
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: EditHeightKey.self, value: geo.size.height)
            }
        )
        .onPreferenceChange(EditHeightKey.self) { totalHeight = $0 }
    }
}

private struct EditHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
