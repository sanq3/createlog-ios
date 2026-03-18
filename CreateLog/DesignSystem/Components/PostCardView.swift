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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(alignment: .top, spacing: 12) {
                AvatarView(initials: post.initials, status: post.status)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(post.name)
                            .font(.clHeadline)
                            .foregroundStyle(Color.clTextPrimary)

                        Text("@\(post.handle)")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)

                        Spacer()

                        Text(post.timeAgo)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    // Work time badge
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 10))
                        Text("今日")
                            .font(.clCaption)
                        Text(post.workTime)
                            .font(.clCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.clTextPrimary)
                        Text("作業")
                            .font(.clCaption)
                    }
                    .foregroundStyle(Color.clTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 6))
                }
            }

            // Content
            Text(post.content)
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
                .lineSpacing(4)
                .padding(.leading, 52)
                .padding(.top, 10)

            // Actions
            HStack(spacing: 0) {
                ActionButton(icon: "bubble.right", count: post.comments) {}

                ActionButton(
                    icon: "arrow.2.squarepath",
                    count: post.reposts,
                    isActive: false,
                    activeColor: .clSuccess
                ) {}

                ActionButton(
                    icon: post.isLiked ? "heart.fill" : "heart",
                    count: post.likes,
                    isActive: post.isLiked,
                    activeColor: .clError
                ) {
                    post.isLiked.toggle()
                    post.likes += post.isLiked ? 1 : -1
                }

                ActionButton(icon: "square.and.arrow.up") {}
            }
            .padding(.leading, 52)
            .padding(.top, 10)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
