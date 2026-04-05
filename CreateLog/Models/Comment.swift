import Foundation

struct Comment: Identifiable, Sendable {
    let id: UUID
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let text: String
    let timestamp: Date
    var likes: Int
    var isLiked: Bool
    let replies: [Comment]

    init(
        id: UUID = UUID(),
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        text: String,
        timestamp: Date = Date(),
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [Comment] = []
    ) {
        self.id = id
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.text = text
        self.timestamp = timestamp
        self.likes = likes
        self.isLiked = isLiked
        self.replies = replies
    }
}

struct Review: Identifiable, Sendable {
    let id: UUID
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let rating: Int
    let text: String
    let timestamp: Date
    var developerReply: String?

    init(
        id: UUID = UUID(),
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        rating: Int,
        text: String = "",
        timestamp: Date = Date(),
        developerReply: String? = nil
    ) {
        self.id = id
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.rating = rating
        self.text = text
        self.timestamp = timestamp
        self.developerReply = developerReply
    }
}
