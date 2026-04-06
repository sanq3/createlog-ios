import SwiftUI

struct PostCardView: View {
    @State var post: Post
    @State private var heartScale: CGFloat = 1.0
    @State private var showReport = false
    @State private var showBlock = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                AvatarView(initials: post.initials, size: 46, status: post.status)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(post.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.clTextPrimary)

                        Text("@\(post.handle)")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)

                        Spacer()

                        Text(post.timeAgo)
                            .font(.system(size: 13))
                            .foregroundStyle(Color.clTextTertiary)

                        Menu {
                            Button {
                                showReport = true
                            } label: {
                                Label("報告する", systemImage: "exclamationmark.bubble")
                            }
                            Button(role: .destructive) {
                                showBlock = true
                            } label: {
                                Label("ブロックする", systemImage: "nosign")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.clTextTertiary)
                                .frame(width: 28, height: 28)
                        }
                    }

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.clAccent)
                            .frame(width: 6, height: 6)
                        Text(post.workTime)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .foregroundStyle(Color.clAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
                }
            }

            Text(post.content)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextPrimary.opacity(0.85))
                .lineSpacing(6)
                .padding(.top, 14)

            mediaView
                .padding(.top, 12)

            actionBar
                .padding(.top, 14)
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 16)
        .sheet(isPresented: $showReport) {
            ReportSheet(targetName: post.name) { _, _ in }
        }
        .sheet(isPresented: $showBlock) {
            BlockConfirmSheet(
                userName: post.name,
                userHandle: post.handle,
                onBlock: {}
            )
        }
    }

    // MARK: - Media

    @ViewBuilder
    private var mediaView: some View {
        if let media = post.media {
            switch media {
            case .images(let images):
                imageGrid(images)
            case .video(let video):
                videoThumbnail(video)
            case .code(let code):
                codeBlock(code)
            }
        }
    }

    private func imageGrid(_ images: [PostImage]) -> some View {
        PostImageGrid(images: images)
    }

    private func videoThumbnail(_ video: PostVideo) -> some View {
        PostVideoThumbnail(video: video)
    }

    private func codeBlock(_ code: PostCode) -> some View {
        PostCodeBlock(code: code, maxLines: 10)
    }

    // MARK: - Actions

    private var actionBar: some View {
        HStack(spacing: 0) {
            actionItem(icon: "bubble.right", count: post.comments)
            Spacer()
            actionItem(icon: "arrow.2.squarepath", count: post.reposts)
            Spacer()

            Button {
                withAnimation(.spring(duration: 0.4, bounce: 0.5)) {
                    post.isLiked.toggle()
                    post.likes += post.isLiked ? 1 : -1
                    heartScale = 1.4
                }
                HapticManager.light()
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    withAnimation(.spring(duration: 0.3)) {
                        heartScale = 1.0
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 15))
                        .scaleEffect(heartScale)
                    Text("\(post.likes)")
                        .font(.system(size: 13))
                        .monospacedDigit()
                }
                .foregroundStyle(post.isLiked ? Color.clError : Color.clTextTertiary)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticManager.light()
            } label: {
                Image(systemName: post.isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15))
                    .foregroundStyle(post.isBookmarked ? Color.clAccent : Color.clTextTertiary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                HapticManager.light()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.clTextTertiary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
            }
            .buttonStyle(.plain)
        }
    }

    private func actionItem(icon: String, count: Int) -> some View {
        Button {
            HapticManager.light()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 15))
                Text("\(count)")
                    .font(.system(size: 13))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.clTextTertiary)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
    }
}
