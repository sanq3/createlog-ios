import SwiftUI

struct PostCardView: View {
    @State var post: Post
    @State private var heartScale: CGFloat = 1.0

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
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
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
        Group {
            switch images.count {
            case 1:
                singleImage(images[0])
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

    private func singleImage(_ image: PostImage) -> some View {
        imagePlaceholder(image, aspectRatio: image.aspectRatio)
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
                    Image(systemName: "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .glassEffect(.regular, in: .circle)
                }
            )
            .overlay(alignment: .bottomTrailing) {
                Text(video.duration)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular, in: .capsule)
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

            Text(code.code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Color.clTextSecondary)
                .lineLimit(10)
                .padding(12)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
