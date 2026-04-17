import SwiftUI

struct ProjectRegistrationView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var platform: ProjectPlatform = .ios
    @State private var storeURL = ""
    @State private var githubURL = ""
    @State private var status: ProjectStatus = .draft
    @State private var iconColor = ColorRGB(red: 0.2, green: 0.25, blue: 0.45)
    @State private var screenshotColors: [ColorRGB] = []
    @State private var tagInput = ""
    @State private var tags: [String] = []

    private let maxScreenshots = 5
    private let maxTags = 5

    private var iconInitials: String {
        name.isEmpty ? "?" : String(name.prefix(1))
    }

    private var canPublish: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    iconSection
                    nameSection
                    descriptionSection
                    platformSection
                    storeURLSection
                    githubURLSection
                    screenshotSection
                    tagSection
                    statusSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(Color.clBackground)
            .navigationTitle("profile.myProducts.register")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("visibility.public") {
                        HapticManager.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canPublish ? Color.clAccent : Color.clTextTertiary)
                    .disabled(!canPublish)
                }
            }
        }
    }

    // MARK: - Icon

    private var iconSection: some View {
        Button {
            HapticManager.light()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                iconColor = ColorRGB(
                    red: Double.random(in: 0.1...0.4),
                    green: Double.random(in: 0.1...0.4),
                    blue: Double.random(in: 0.1...0.5)
                )
            }
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: iconColor.red, green: iconColor.green, blue: iconColor.blue),
                            Color(
                                red: iconColor.red * 0.6,
                                green: iconColor.green * 0.6,
                                blue: iconColor.blue * 0.6
                            ),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(iconInitials)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: Color(red: iconColor.red, green: iconColor.green, blue: iconColor.blue).opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.top, 8)

        // Hint
        .overlay(alignment: .bottom) {
            Text("onboarding.project.icon.hint")
                .font(.caption2)
                .foregroundStyle(Color.clTextTertiary)
                .offset(y: 24)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Name

    private var nameSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 8) {
                formLabel("アプリ名")
                TextField("onboarding.project.name.input", text: $name)
                    .font(.body)
                    .foregroundStyle(Color.clTextPrimary)
            }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 8) {
                formLabel("説明")
                TextField("onboarding.project.desc.input", text: $description, axis: .vertical)
                    .font(.body)
                    .foregroundStyle(Color.clTextPrimary)
                    .lineLimit(3...6)
            }
        }
    }

    // MARK: - Platform

    private var platformSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("プラットフォーム")
                Picker("project.platform.label", selection: $platform) {
                    ForEach(ProjectPlatform.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Store URL

    private var storeURLSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    formLabel("ストアURL")
                    optionalBadge
                }
                TextField("https://apps.apple.com/...", text: $storeURL)
                    .font(.body)
                    .foregroundStyle(Color.clTextPrimary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - GitHub URL

    private var githubURLSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    formLabel("GitHub URL")
                    optionalBadge
                }
                TextField("https://github.com/...", text: $githubURL)
                    .font(.body)
                    .foregroundStyle(Color.clTextPrimary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        }
    }

    // MARK: - Screenshots

    private var screenshotSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                formLabel("スクリーンショット")
                Spacer()
                Text("\(screenshotColors.count)/\(maxScreenshots)")
                    .font(.caption)
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(screenshotColors.enumerated()), id: \.offset) { index, color in
                        screenshotCard(color: color, index: index)
                    }

                    if screenshotColors.count < maxScreenshots {
                        addScreenshotButton
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
        }
    }

    private func screenshotCard(color: ColorRGB, index: Int) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: color.red, green: color.green, blue: color.blue),
                        Color(red: color.red * 0.7, green: color.green * 0.7, blue: color.blue * 1.2),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 120, height: 200)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    HapticManager.light()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        _ = screenshotColors.remove(at: index)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            .transition(.scale.combined(with: .opacity))
    }

    private var addScreenshotButton: some View {
        Button {
            HapticManager.light()
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                let newColor = ColorRGB(
                    red: Double.random(in: 0.1...0.35),
                    green: Double.random(in: 0.1...0.3),
                    blue: Double.random(in: 0.15...0.4)
                )
                screenshotColors.append(newColor)
            }
        } label: {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.clBorder, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .frame(width: 120, height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 28, weight: .light))
                        Text("common.add")
                            .font(.caption)
                    }
                    .foregroundStyle(Color.clTextTertiary)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tags

    private var tagSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    formLabel("タグ")
                    Spacer()
                    Text("\(tags.count)/\(maxTags)")
                        .font(.caption)
                        .foregroundStyle(Color.clTextTertiary)
                }

                if !tags.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                            tagChip(tag, index: index)
                        }
                    }
                }

                if tags.count < maxTags {
                    HStack(spacing: 8) {
                        TextField("recording.tag.input", text: $tagInput)
                            .font(.body)
                            .foregroundStyle(Color.clTextPrimary)
                            .onSubmit {
                                addTag()
                            }

                        Button {
                            addTag()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(
                                    tagInput.trimmingCharacters(in: .whitespaces).isEmpty
                                        ? Color.clTextTertiary
                                        : Color.clAccent
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(tagInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private func tagChip(_ tag: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.subheadline)
                .foregroundStyle(Color.clAccent)

            Button {
                HapticManager.light()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    tags.remove(at: index)
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
        .background(
            Capsule()
                .fill(Color.clAccent.opacity(0.12))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.clAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, tags.count < maxTags, !tags.contains(trimmed) else { return }
        HapticManager.light()
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            tags.append(trimmed)
        }
        tagInput = ""
    }

    // MARK: - Status

    private var statusSection: some View {
        formCard {
            VStack(alignment: .leading, spacing: 12) {
                formLabel("ステータス")
                Picker("recording.status", selection: $status) {
                    ForEach(ProjectStatus.allCases, id: \.self) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Helpers

    private func formLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(Color.clTextSecondary)
    }

    private var optionalBadge: some View {
        Text("common.optional")
            .font(.caption2)
            .foregroundStyle(Color.clTextTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.clSurfaceLow)
            )
    }

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clSurfaceHigh)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
            )
    }
}

// MARK: - FlowLayout


#Preview {
    ProjectRegistrationView()
        .preferredColorScheme(.dark)
}
