import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    @State private var isLiked: Bool
    @State private var likeCount: Int

    init(article: Article) {
        self.article = article
        self._isLiked = State(initialValue: article.isLiked)
        self._likeCount = State(initialValue: article.likes)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                coverArea
                contentArea
            }
        }
        .background(Color.clBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cover

    private var coverArea: some View {
        let base = article.coverColor
        return LinearGradient(
            colors: [
                Color(red: base.red, green: base.green, blue: base.blue),
                Color(red: base.red * 0.6, green: base.green * 0.6, blue: base.blue * 0.8),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 200)
        .overlay(alignment: .bottomLeading) {
            Text(article.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
                .padding(20)
        }
    }

    // MARK: - Content

    private var contentArea: some View {
        VStack(alignment: .leading, spacing: 24) {
            metaInfo
            Divider().foregroundStyle(Color.clBorder)
            articleBody
            if !article.tags.isEmpty {
                tagRow
            }
            Divider().foregroundStyle(Color.clBorder)
            actionRow
        }
        .padding(20)
    }

    private var metaInfo: some View {
        HStack(spacing: 12) {
            Button {
                // TODO: プロフィール遷移
            } label: {
                AvatarView(initials: article.authorInitials, size: 40)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    // TODO: プロフィール遷移
                } label: {
                    Text(article.authorName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.clTextPrimary)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Text("@\(article.authorHandle)")
                    Text("・")
                    Text(formattedDate)
                    Text("・")
                    Text(DurationFormatter.isJapanese ? "\(article.readingTime)分で読める" : "\(article.readingTime) min read")
                }
                .font(.caption)
                .foregroundStyle(Color.clTextTertiary)
            }
        }
    }

    private var articleBody: some View {
        Text(article.body)
            .font(.system(size: 16))
            .foregroundStyle(Color.clTextPrimary)
            .lineSpacing(8)
    }

    private var tagRow: some View {
        FlowLayout(spacing: 8) {
            ForEach(article.tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .foregroundStyle(Color.clAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.clAccent.opacity(0.12))
                    )
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 24) {
            Button {
                HapticManager.light()
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    isLiked.toggle()
                    likeCount += isLiked ? 1 : -1
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? Color.clError : Color.clTextTertiary)
                    Text("\(likeCount)")
                        .foregroundStyle(Color.clTextSecondary)
                }
                .font(.subheadline)
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                Image(systemName: "bubble.right")
                    .foregroundStyle(Color.clTextTertiary)
                Text("\(article.comments)")
                    .foregroundStyle(Color.clTextSecondary)
            }
            .font(.subheadline)

            Spacer()

            Button {
                HapticManager.light()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Color.clTextTertiary)
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: article.publishedAt)
    }
}

// MARK: - Flow Layout

