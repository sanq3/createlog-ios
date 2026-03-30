import Foundation

struct Comment: Identifiable {
    let id = UUID()
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let text: String
    let timestamp: Date
    var likes: Int
    var isLiked: Bool
    let replies: [Comment]

    init(
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        text: String,
        timestamp: Date = Date(),
        likes: Int = 0,
        isLiked: Bool = false,
        replies: [Comment] = []
    ) {
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

struct Review: Identifiable {
    let id = UUID()
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let rating: Int
    let text: String
    let timestamp: Date
    var developerReply: String?

    init(
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        rating: Int,
        text: String = "",
        timestamp: Date = Date(),
        developerReply: String? = nil
    ) {
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.rating = rating
        self.text = text
        self.timestamp = timestamp
        self.developerReply = developerReply
    }
}
