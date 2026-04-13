import Foundation

struct Article: Identifiable, Sendable {
    let id: UUID
    let title: String
    let body: String
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let authorAvatarUrl: String?
    let coverColor: ColorRGB
    let publishedAt: Date
    let readingTime: Int
    var likes: Int
    var comments: Int
    var isLiked: Bool
    let visibility: ArticleVisibility
    let tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        authorAvatarUrl: String? = nil,
        coverColor: ColorRGB = ColorRGB(red: 0.15, green: 0.2, blue: 0.3),
        publishedAt: Date = Date(),
        readingTime: Int = 5,
        likes: Int = 0,
        comments: Int = 0,
        isLiked: Bool = false,
        visibility: ArticleVisibility = .public,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.authorAvatarUrl = authorAvatarUrl
        self.coverColor = coverColor
        self.publishedAt = publishedAt
        self.readingTime = readingTime
        self.likes = likes
        self.comments = comments
        self.isLiked = isLiked
        self.visibility = visibility
        self.tags = tags
    }
}

enum ArticleVisibility: Sendable {
    case `public`
    case followersOnly
    case draft
}
