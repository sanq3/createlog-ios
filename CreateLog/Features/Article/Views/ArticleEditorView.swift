import SwiftUI

struct ArticleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var bodyText = ""
    @State private var visibility: ArticleVisibility = .public
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @State private var isSaved = false
    @State private var saveTask: Task<Void, Never>?

    private let maxTags = 5

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                editorContent
                Divider().foregroundStyle(Color.clBorder)
                bottomBar
            }
            .background(Color.clBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        HapticManager.light()
                        dismiss()
                    }
                    .foregroundStyle(Color.clTextSecondary)
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .principal) {
                    if isSaved {
                        Text("保存済み")
                            .font(.caption)
                            .foregroundStyle(Color.clTextTertiary)
                            .transition(.opacity)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("公開") {
                        HapticManager.light()
                        publish()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(canPublish ? Color.clAccent : Color.clTextTertiary)
                    .disabled(!canPublish)
                    .buttonStyle(.plain)
                }
            }
        }
        .onChange(of: title) { markDirty() }
        .onChange(of: bodyText) { markDirty() }
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                titleField
                dividerLine
                bodyField
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private var titleField: some View {
        TextField("タイトル", text: $title, axis: .vertical)
            .font(.system(size: 24, weight: .bold))
            .foregroundStyle(Color.clTextPrimary)
            .padding(.vertical, 12)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.clBorder.opacity(0.5))
            .frame(height: 1)
    }

    private var bodyField: some View {
        TextField("本文を書く...", text: $bodyText, axis: .vertical)
            .font(.system(size: 16))
            .foregroundStyle(Color.clTextPrimary)
            .lineSpacing(6)
            .padding(.vertical, 12)
            .frame(minHeight: 300, alignment: .topLeading)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 12) {
            tagSection
            visibilityPicker
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.clSurfaceHigh)
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !tags.isEmpty {
                tagChips
            }

            if tags.count < maxTags {
                tagInputField
            }
        }
    }

    private var tagChips: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                tagChip(tag)
            }
        }
    }

    private func tagChip(_ tag: String) -> some View {
        HStack(spacing: 4) {
            Text(tag)
                .font(.caption)
                .foregroundStyle(Color.clAccent)

            Button {
                HapticManager.light()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    tags.removeAll { $0 == tag }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.clAccent.opacity(0.12))
        )
    }

    private var tagInputField: some View {
        HStack(spacing: 8) {
            Text("#")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.clTextTertiary)

            TextField("タグを追加（最大\(maxTags)つ）", text: $tagInput)
                .font(.subheadline)
                .foregroundStyle(Color.clTextPrimary)
                .onSubmit {
                    addTag()
                }
        }
    }

    private var visibilityPicker: some View {
        HStack(spacing: 0) {
            ForEach(visibilityOptions, id: \.value) { option in
                let isSelected = visibility == option.value
                Button {
                    HapticManager.light()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        visibility = option.value
                    }
                } label: {
                    Text(option.label)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color.clAccent : Color.clTextTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? Capsule().fill(Color.clAccent.opacity(0.12))
                                : Capsule().fill(Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(Color.clBackground)
        )
    }

    // MARK: - Helpers

    private var visibilityOptions: [(label: String, value: ArticleVisibility)] {
        [
            ("全体公開", .public),
            ("フォロワー限定", .followersOnly),
            ("下書き", .draft),
        ]
    }

    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, tags.count < maxTags, !tags.contains(trimmed) else { return }
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            tags.append(trimmed)
        }
        tagInput = ""
    }

    private func markDirty() {
        isSaved = false
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                isSaved = true
            }
        }
    }

    private func publish() {
        // 公開処理（バックエンド接続時に実装）
        dismiss()
    }
}

// MARK: - Flow Layout

