import Foundation

struct Post: Identifiable, Sendable {
    let id: UUID
    let name: String
    let handle: String
    let status: OnlineStatus
    /// 投稿の作成日時 (SSOT)。timeAgo表示はここから毎回計算する
    let createdAt: Date
    /// 作業時間の分数 (0なら未記録)。workTime表示はここから毎回フォーマットする
    let workMinutes: Int
    let content: String
    var likes: Int
    var reposts: Int
    var comments: Int
    var isLiked: Bool = false
    var isBookmarked: Bool = false
    let media: PostMedia?

    init(
        id: UUID = UUID(),
        name: String,
        handle: String,
        status: OnlineStatus,
        createdAt: Date = Date(),
        workMinutes: Int = 0,
        content: String,
        likes: Int = 0,
        reposts: Int = 0,
        comments: Int = 0,
        isLiked: Bool = false,
        isBookmarked: Bool = false,
        media: PostMedia? = nil
    ) {
        self.id = id
        self.name = name
        self.handle = handle
        self.status = status
        self.createdAt = createdAt
        self.workMinutes = workMinutes
        self.content = content
        self.likes = likes
        self.reposts = reposts
        self.comments = comments
        self.isLiked = isLiked
        self.isBookmarked = isBookmarked
        self.media = media
    }

    // MARK: - UI Derived Properties

    /// 表示用の頭文字 (name先頭文字から導出)
    var initials: String {
        name.isEmpty ? "?" : String(name.prefix(1))
    }

    /// 表示用の相対時間 (毎回計算)
    var timeAgo: String {
        RelativeTimeFormatter.format(from: createdAt)
    }

    /// 表示用の作業時間 (例: "3h 20m")
    var workTime: String {
        guard workMinutes > 0 else { return "" }
        let h = workMinutes / 60
        let m = workMinutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

enum PostMedia {
    case images([PostImage])
    case video(PostVideo)
    case code(PostCode)
}

struct PostCode: Identifiable, Sendable {
    let id: UUID
    let code: String
    let language: String

    init(id: UUID = UUID(), code: String, language: String) {
        self.id = id
        self.code = code
        self.language = language
    }
}

struct PostImage: Identifiable, Sendable {
    let id: UUID
    let placeholderColor: ColorRGB
    let aspectRatio: CGFloat

    init(id: UUID = UUID(), placeholderColor: ColorRGB, aspectRatio: CGFloat) {
        self.id = id
        self.placeholderColor = placeholderColor
        self.aspectRatio = aspectRatio
    }
}

struct PostVideo: Identifiable, Sendable {
    let id: UUID
    let placeholderColor: ColorRGB
    let duration: String
    let aspectRatio: CGFloat

    init(id: UUID = UUID(), placeholderColor: ColorRGB, duration: String, aspectRatio: CGFloat) {
        self.id = id
        self.placeholderColor = placeholderColor
        self.duration = duration
        self.aspectRatio = aspectRatio
    }
}
