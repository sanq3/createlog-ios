import PhotosUI
import SwiftUI

// MARK: - Auto-Detected Content Type

enum ComposeContentType: String {
    case post = "投稿"
    case article = "記事"
    case codeSnippet = "コード"

    var icon: String {
        switch self {
        case .post: "text.bubble"
        case .article: "doc.text"
        case .codeSnippet: "chevron.left.forwardslash.chevron.right"
        }
    }
}

// MARK: - ComposeView

struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachedImages: [AttachedImageData] = []
    @State private var attachedCode: AttachedCode?
    @State private var showCodeEditor = false

    private let articleThreshold = 300
    private let maxImages = 4
    private let user = MockData.currentUser

    private var detectedType: ComposeContentType {
        if attachedCode != nil {
            return .codeSnippet
        } else if text.count > articleThreshold {
            return .article
        }
        return .post
    }

    private var canPost: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !attachedImages.isEmpty || attachedCode != nil
        return hasText || hasMedia
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        AvatarView(
                            initials: user.initials,
                            size: 40,
                            status: .offline
                        )

                        AutoFocusTextView(text: $text)
                            .frame(minHeight: 160)
                            .overlay(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("いまなにしてる?")
                                        .font(.system(size: 17))
                                        .foregroundStyle(Color.clTextTertiary)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    if !attachedImages.isEmpty {
                        attachedImagesSection
                    }

                    if let code = attachedCode {
                        attachedCodeSection(code)
                    }
                }
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.light()
                        dismiss()
                    } label: {
                        Text("キャンセル")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.clTextPrimary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.medium()
                        dismiss()
                    } label: {
                        Text("投稿")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(canPost ? Color.clAccent : Color.clAccent.opacity(0.4))
                    }
                    .disabled(!canPost)
                }
            }
            .toolbar(.visible, for: .bottomBar)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: maxImages - attachedImages.count,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                attachedImages.count >= maxImages
                                    ? Color.clTextTertiary
                                    : Color.clAccent
                            )
                    }
                    .disabled(attachedImages.count >= maxImages)

                    Button {
                        HapticManager.light()
                        showCodeEditor = true
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                attachedCode != nil
                                    ? Color.clTextTertiary
                                    : Color.clAccent
                            )
                    }
                    .disabled(attachedCode != nil)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: detectedType.icon)
                            .font(.system(size: 11, weight: .medium))

                        Text(detectedType.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(badgeColor.opacity(0.12))
                    )
                    .animation(.spring(duration: 0.35, bounce: 0.15), value: detectedType)
                }
            }
            .sheet(isPresented: $showCodeEditor) {
                CodeAttachmentSheet(attachedCode: $attachedCode)
            }
            .onChange(of: selectedPhotos) { _, newItems in
                handlePhotoSelection(newItems)
            }
        }
    }

    // MARK: - Photo Selection

    private func handlePhotoSelection(_ items: [PhotosPickerItem]) {
        for item in items {
            guard attachedImages.count < maxImages else { break }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data)
                {
                    await MainActor.run {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            attachedImages.append(AttachedImageData(image: uiImage))
                        }
                    }
                }
            }
        }
        selectedPhotos = []
    }

    // MARK: - Attached Images Section

    private var attachedImagesSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(attachedImages) { imageData in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: imageData.image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(Color.clBorder, lineWidth: 1)
                            )

                        Button {
                            HapticManager.light()
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                attachedImages.removeAll { $0.id == imageData.id }
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
            .padding(.horizontal, 68)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Attached Code Section

    private func attachedCodeSection(_ code: AttachedCode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(code.language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clAccent)

                Spacer()

                Button {
                    HapticManager.light()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        attachedCode = nil
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.clTextTertiary)
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color.clSurfaceHigh)
                        )
                }
                .buttonStyle(.plain)
            }

            Text(code.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.clTextSecondary)
                .lineLimit(8)
                .padding(.top, 8)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.clSurfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 68)
        .padding(.vertical, 12)
    }

    private var badgeColor: Color {
        switch detectedType {
        case .post: .clAccent
        case .article: .orange
        case .codeSnippet: .blue
        }
    }
}

// MARK: - Attached Image Data

private struct AttachedImageData: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Attached Code Model

struct AttachedCode {
    var code: String
    var language: String
}

// MARK: - Code Attachment Sheet

private struct CodeAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var attachedCode: AttachedCode?
    @State private var code = ""
    @State private var selectedLanguage = "Swift"

    private let languages = [
        "Swift", "Kotlin", "TypeScript", "JavaScript",
        "Python", "Go", "Rust", "Java", "C++", "Ruby",
        "PHP", "Dart", "SQL", "Shell", "HTML", "CSS",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(languages, id: \.self) { lang in
                            Button {
                                HapticManager.light()
                                selectedLanguage = lang
                            } label: {
                                Text(lang)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(
                                        selectedLanguage == lang
                                            ? .white
                                            : Color.clTextSecondary
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(
                                                selectedLanguage == lang
                                                    ? Color.clAccent
                                                    : Color.clSurfaceHigh
                                            )
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }

                Divider()
                    .overlay(Color.clBorder)

                TextEditor(text: $code)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(Color.clTextPrimary)
                    .scrollContentBackground(.hidden)
                    .padding(16)
            }
            .background(Color.clBackground)
            .navigationTitle("コードを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        HapticManager.medium()
                        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            attachedCode = AttachedCode(code: trimmed, language: selectedLanguage)
                        }
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(
                        code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.clAccent.opacity(0.4)
                            : Color.clAccent
                    )
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(28)
    }
}
