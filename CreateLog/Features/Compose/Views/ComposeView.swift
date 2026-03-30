import SwiftUI

// MARK: - Content Type

enum ComposeContentType: Identifiable, CaseIterable {
    case post
    case article
    case project
    case codeSnippet
    case video

    var id: Self { self }

    var title: String {
        switch self {
        case .post: "投稿"
        case .article: "記事"
        case .project: "プロジェクト"
        case .codeSnippet: "コードスニペット"
        case .video: "動画"
        }
    }

    var icon: String {
        switch self {
        case .post: "text.bubble"
        case .article: "doc.text"
        case .project: "hammer"
        case .codeSnippet: "chevron.left.forwardslash.chevron.right"
        case .video: "play.rectangle"
        }
    }

    var description: String {
        switch self {
        case .post: "テキストや画像を共有"
        case .article: "長文の技術記事を書く"
        case .project: "プロジェクトを紹介"
        case .codeSnippet: "コードを共有"
        case .video: "動画をアップロード"
        }
    }
}

// MARK: - ComposeView

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedType: ComposeContentType?
    @State private var showTypeSelector = true
    @State private var text = ""
    @State private var attachedImages: [AttachedImage] = []

    private let maxCharacters = 280
    private let user = MockData.currentUser

    private var remainingCharacters: Int {
        maxCharacters - text.count
    }

    private var characterProgress: Double {
        Double(text.count) / Double(maxCharacters)
    }

    private var progressColor: Color {
        if remainingCharacters <= 0 {
            return .clError
        } else if remainingCharacters <= 20 {
            return .orange
        }
        return .clAccent
    }

    private var canPost: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingCharacters >= 0
    }

    var body: some View {
        Group {
            if let type = selectedType {
                if type == .post {
                    composePostView
                } else {
                    placeholderView(for: type)
                }
            }
        }
        .background(Color.clBackground)
        .sheet(isPresented: $showTypeSelector) {
            if selectedType == nil {
                dismiss()
            }
        } content: {
            contentTypeSelectorSheet
        }
    }

    // MARK: - Content Type Selector Sheet

    private var contentTypeSelectorSheet: some View {
        NavigationStack {
            VStack(spacing: 8) {
                ForEach(ComposeContentType.allCases) { type in
                    Button {
                        HapticManager.light()
                        selectedType = type
                        showTypeSelector = false
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color.clAccent)
                                .frame(width: 40, height: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.clAccent.opacity(0.12))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(type.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.clTextPrimary)

                                Text(type.description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.clTextTertiary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.clTextTertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.clSurfaceHigh)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color.clBackground)
            .navigationTitle("作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }

    // MARK: - Compose Post View

    private var composePostView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Avatar + TextEditor
                        HStack(alignment: .top, spacing: 12) {
                            AvatarView(
                                initials: user.initials,
                                size: 40,
                                status: user.status
                            )

                            ZStack(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("いまなにしてる?")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.clTextTertiary)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }

                                TextEditor(text: $text)
                                    .font(.system(size: 17))
                                    .foregroundStyle(Color.clTextPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(.leading, -5)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // Attached images
                        if !attachedImages.isEmpty {
                            attachedImagesSection
                        }
                    }
                }

                Divider()
                    .overlay(Color.clBorder)

                // Bottom toolbar
                composeToolbar
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .font(.system(size: 16))
                    .foregroundStyle(Color.clTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.medium()
                        // 投稿処理（将来実装）
                        dismiss()
                    } label: {
                        Text("投稿する")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(canPost ? Color.clAccent : Color.clAccent.opacity(0.4))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPost)
                }
            }
        }
    }

    // MARK: - Attached Images Section

    private var attachedImagesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachedImages) { image in
                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(image.placeholderColor)
                            .frame(width: 120, height: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.clBorder, lineWidth: 1)
                            )
                            .overlay(
                                Image(systemName: "photo")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.white.opacity(0.3))
                            )

                        Button {
                            HapticManager.light()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                attachedImages.removeAll { $0.id == image.id }
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(.black.opacity(0.6))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .offset(x: -6, y: 6)
                    }
                }
            }
            .padding(.horizontal, 68) // align with text editor
            .padding(.vertical, 12)
        }
    }

    // MARK: - Compose Toolbar

    private var composeToolbar: some View {
        HStack(spacing: 0) {
            Button {
                HapticManager.light()
                guard attachedImages.count < 4 else { return }
                let colors: [Color] = [
                    Color(red: 0.15, green: 0.25, blue: 0.4),
                    Color(red: 0.25, green: 0.15, blue: 0.3),
                    Color(red: 0.12, green: 0.2, blue: 0.25),
                    Color(red: 0.2, green: 0.18, blue: 0.35),
                ]
                let color = colors[attachedImages.count % colors.count]
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    attachedImages.append(AttachedImage(placeholderColor: color))
                }
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 18))
                    .foregroundStyle(
                        attachedImages.count >= 4
                            ? Color.clTextTertiary
                            : Color.clAccent
                    )
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(attachedImages.count >= 4)

            Spacer()

            // Character count ring
            characterCountView
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.clBackground)
    }

    // MARK: - Character Count Ring

    private var characterCountView: some View {
        ZStack {
            Circle()
                .stroke(Color.clBorder, lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: min(characterProgress, 1.0))
                .stroke(progressColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if remainingCharacters <= 20 {
                Text("\(remainingCharacters)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(progressColor)
            }
        }
        .frame(width: 30, height: 30)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: text.count)
    }

    // MARK: - Placeholder Views (Article, Project, CodeSnippet, Video)

    private func placeholderView(for type: ComposeContentType) -> some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: type.icon)
                    .font(.system(size: 48))
                    .foregroundStyle(Color.clAccent.opacity(0.5))

                Text("\(type.title)の作成")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)

                Text("この機能は今後実装予定です")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                }
            }
        }
    }
}

// MARK: - Attached Image Model

private struct AttachedImage: Identifiable {
    let id = UUID()
    let placeholderColor: Color
}
