import SwiftUI

struct PostData: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initials: String
    let status: OnlineStatus
    let workTime: String
    let content: String
    let timeAgo: String
    var likes: Int
    var reposts: Int
    var comments: Int
    var isLiked: Bool = false
}

struct PostCardView: View {
    @State var post: PostData
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
                    .background(
                        Capsule()
                            .fill(Color.clAccent.opacity(0.1))
                            .overlay(Capsule().strokeBorder(Color.clAccent.opacity(0.15), lineWidth: 1))
                    )
                }
            }

            Text(post.content)
                .font(.system(size: 15))
                .foregroundStyle(Color.clTextPrimary.opacity(0.85))
                .lineSpacing(6)
                .padding(.top, 14)

            HStack(spacing: 2) {
                actionItem(icon: "bubble.right", count: post.comments)
                actionItem(icon: "arrow.2.squarepath", count: post.reposts)

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
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.clTextTertiary)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 14)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color.clSurfaceHigh)
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
        )
        .padding(.horizontal, 16)
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
