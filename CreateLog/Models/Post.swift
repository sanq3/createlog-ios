import Foundation

struct Post: Identifiable, Sendable {
    let id: UUID
    /// 投稿者の user_id (profiles.id)。ブロック操作などで使う。MockData 経由では nil。
    let userId: UUID?
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
    /// 投稿者のアバター画像 URL。PostDTO.authorAvatarUrl 経由で渡される。
    let authorAvatarUrl: String?

    init(
        id: UUID = UUID(),
        userId: UUID? = nil,
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
        media: PostMedia? = nil,
        authorAvatarUrl: String? = nil
    ) {
        self.id = id
        self.userId = userId
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
        self.authorAvatarUrl = authorAvatarUrl
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
    /// Full-size 画像 URL。Phase 1/2 は client 生成 1920px、Phase 3 は CDN original。
    /// nil なら mock/旧データ (placeholderColor で描画)。
    let url: String?
    /// Thumbnail URL (480px)。Phase 1/2 は client 生成、Phase 3 は nil で CDN 動的生成。
    let thumbUrl: String?
    let placeholderColor: ColorRGB
    let aspectRatio: CGFloat

    init(
        id: UUID = UUID(),
        url: String? = nil,
        thumbUrl: String? = nil,
        placeholderColor: ColorRGB = ColorRGB(red: 0.5, green: 0.5, blue: 0.5),
        aspectRatio: CGFloat = 1.0
    ) {
        self.id = id
        self.url = url
        self.thumbUrl = thumbUrl
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
