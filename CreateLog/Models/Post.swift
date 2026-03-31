import Foundation

struct Post: Identifiable {
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
    let media: PostMedia?

    init(
        name: String,
        handle: String,
        initials: String,
        status: OnlineStatus,
        workTime: String,
        content: String,
        timeAgo: String,
        likes: Int,
        reposts: Int,
        comments: Int,
        isLiked: Bool = false,
        media: PostMedia? = nil
    ) {
        self.name = name
        self.handle = handle
        self.initials = initials
        self.status = status
        self.workTime = workTime
        self.content = content
        self.timeAgo = timeAgo
        self.likes = likes
        self.reposts = reposts
        self.comments = comments
        self.isLiked = isLiked
        self.media = media
    }
}

enum PostMedia {
    case images([PostImage])
    case video(PostVideo)
    case code(PostCode)
}

struct PostCode: Identifiable {
    let id = UUID()
    let code: String
    let language: String
}

struct PostImage: Identifiable {
    let id = UUID()
    let placeholderColor: ColorRGB
    let aspectRatio: CGFloat
}

struct PostVideo: Identifiable {
    let id = UUID()
    let placeholderColor: ColorRGB
    let duration: String
    let aspectRatio: CGFloat
}
