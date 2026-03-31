import SwiftUI

struct PostDetailView: View {
    @State var post: Post
    @State private var comments: [Comment] = MockData.comments
    @State private var commentText = ""
    @State private var heartScale: CGFloat = 1.0
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    postHeader
                    postBody
                    mediaSection
                    timestampRow
                    statsRow
                    Divider().foregroundStyle(Color.clBorder).padding(.horizontal, 16)
                    actionBar
                    Divider().foregroundStyle(Color.clBorder).padding(.horizontal, 16)
                    commentsSection
                }
                .padding(.bottom, 80)
            }
            .scrollDismissesKeyboard(.interactively)

            commentInputBar
        }
        .background(Color.clBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("投稿")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.clTextPrimary)
            }
        }
    }

    // MARK: - Post Header

    private var postHeader: some View {
        HStack(spacing: 12) {
            AvatarView(initials: post.initials, size: 48, status: post.status)

            VStack(alignment: .leading, spacing: 2) {
                Text(post.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                Text("@\(post.handle)")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    // MARK: - Post Body

    private var postBody: some View {
        Text(post.content)
            .font(.system(size: 17))
            .foregroundStyle(Color.clTextPrimary)
            .lineSpacing(6)
            .padding(.horizontal, 16)
            .padding(.top, 14)
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaSection: some View {
        if let media = post.media {
            Group {
                switch media {
                case .images(let images):
                    imageGrid(images)
                case .video(let video):
                    videoThumbnail(video)
                case .code(let code):
                    codeBlock(code)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func imageGrid(_ images: [PostImage]) -> some View {
        Group {
            switch images.count {
            case 1:
                imagePlaceholder(images[0], aspectRatio: images[0].aspectRatio)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            case 2:
                HStack(spacing: 3) {
                    imagePlaceholder(images[0], aspectRatio: 4 / 5)
                    imagePlaceholder(images[1], aspectRatio: 4 / 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
            case 3:
                HStack(spacing: 3) {
                    imagePlaceholder(images[0], aspectRatio: 3 / 4)
                    VStack(spacing: 3) {
                        imagePlaceholder(images[1], aspectRatio: nil)
                        imagePlaceholder(images[2], aspectRatio: nil)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            default:
                let clamped = Array(images.prefix(4))
                VStack(spacing: 3) {
                    HStack(spacing: 3) {
                        imagePlaceholder(clamped[0], aspectRatio: nil)
                        imagePlaceholder(clamped[1], aspectRatio: nil)
                    }
                    HStack(spacing: 3) {
                        imagePlaceholder(clamped[2], aspectRatio: nil)
                        if clamped.count > 3 {
                            imagePlaceholder(clamped[3], aspectRatio: nil)
                        }
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func imagePlaceholder(_ image: PostImage, aspectRatio: CGFloat?) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(
                            red: image.placeholderColor.red,
                            green: image.placeholderColor.green,
                            blue: image.placeholderColor.blue
                        ),
                        Color(
                            red: image.placeholderColor.red * 0.7,
                            green: image.placeholderColor.green * 0.7,
                            blue: image.placeholderColor.blue * 0.7
                        ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(aspectRatio, contentMode: .fill)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.3))
            )
    }

    private func videoThumbnail(_ video: PostVideo) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(
                            red: video.placeholderColor.red,
                            green: video.placeholderColor.green,
                            blue: video.placeholderColor.blue
                        ),
                        Color(
                            red: video.placeholderColor.red * 0.6,
                            green: video.placeholderColor.green * 0.6,
                            blue: video.placeholderColor.blue * 0.6
                        ),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .aspectRatio(video.aspectRatio, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 52, height: 52)
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
            )
            .overlay(alignment: .bottomTrailing) {
                Text(video.duration)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.black.opacity(0.6)))
                    .padding(10)
            }
    }

    private func codeBlock(_ code: PostCode) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(code.language)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.clAccent)

                Spacer()

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clSurfaceHigh)

            Text(code.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.clTextSecondary)
                .padding(12)
        }
        .background(Color.clSurfaceLow)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.clBorder, lineWidth: 1)
        )
    }

    // MARK: - Timestamp

    private var timestampRow: some View {
        Text("14:30 \u{30FB} 2026\u{5E74}3\u{6708}28\u{65E5}")
            .font(.system(size: 14))
            .foregroundStyle(Color.clTextTertiary)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 14)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 20) {
            statItem(count: post.reposts, label: "リポスト")
            statItem(count: post.likes, label: "いいね")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func statItem(count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.clTextPrimary)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color.clTextTertiary)
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Spacer()

            actionButton(icon: "bubble.right", count: post.comments)

            Spacer()

            actionButton(icon: "arrow.2.squarepath", count: post.reposts)

            Spacer()

            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                    post.isLiked.toggle()
                    post.likes += post.isLiked ? 1 : -1
                    heartScale = 1.4
                }
                HapticManager.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    withAnimation(.spring(duration: 0.3)) {
                        heartScale = 1.0
                    }
                }
            } label: {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18))
                    .scaleEffect(heartScale)
                    .foregroundStyle(post.isLiked ? Color.clError : Color.clTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticManager.light()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.clTextTertiary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func actionButton(icon: String, count: Int) -> some View {
        Button {
            HapticManager.light()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.clTextTertiary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Comments

    private var commentsSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(comments) { comment in
                commentRow(comment)
                ForEach(comment.replies) { reply in
                    replyRow(reply)
                }
            }
        }
    }

    private func commentRow(_ comment: Comment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(initials: comment.authorInitials, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(comment.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(comment.authorHandle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Text(comment.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineSpacing(4)

                    commentMeta(comment)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().foregroundStyle(Color.clBorder).padding(.leading, 62)
        }
    }

    private func replyRow(_ reply: Comment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                AvatarView(initials: reply.authorInitials, size: 36)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(reply.authorName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(reply.authorHandle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Text(reply.text)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineSpacing(4)

                    commentMeta(reply)
                }
            }
            .padding(.leading, 40)
            .padding(.trailing, 16)
            .padding(.vertical, 12)
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.clBorder)
                    .frame(width: 2)
                    .padding(.leading, 34)
                    .padding(.vertical, 4)
            }

            Divider().foregroundStyle(Color.clBorder).padding(.leading, 62)
        }
    }

    private func commentMeta(_ comment: Comment) -> some View {
        HStack(spacing: 16) {
            Text(relativeTime(from: comment.timestamp))
                .font(.system(size: 12))
                .foregroundStyle(Color.clTextTertiary)

            if comment.likes > 0 {
                Text("いいね \(comment.likes)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.clTextTertiary)
            }

            Text("返信")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
        .padding(.top, 4)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            Divider().foregroundStyle(Color.clBorder)

            HStack(spacing: 10) {
                AvatarView(
                    initials: MockData.currentUser.initials,
                    size: 32,
                    status: MockData.currentUser.status
                )

                TextField("コメントを追加...", text: $commentText)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.clTextPrimary)
                    .focused($isCommentFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.clSurfaceHigh)
                    )

                if !commentText.isEmpty {
                    Button {
                        HapticManager.light()
                        commentText = ""
                        isCommentFocused = false
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.clAccent)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .animation(.spring(duration: 0.35, bounce: 0.15), value: commentText.isEmpty)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Helpers

    private func relativeTime(from date: Date) -> String {
        RelativeTimeFormatter.format(from: date)
    }
}
