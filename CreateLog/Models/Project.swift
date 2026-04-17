import Foundation

struct Project: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let iconInitials: String
    let iconColor: ColorRGB
    /// Supabase Storage の icon URL (apps.icon_url)。nil なら iconColor + iconInitials の gradient fallback。
    let iconUrl: String?
    let platform: ProjectPlatform
    let status: ProjectStatus
    let storeURL: String?
    let githubURL: String?
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let authorAvatarUrl: String?
    let screenshotColors: [ColorRGB]
    let averageRating: Double
    let reviewCount: Int
    let likes: Int
    let tags: [String]
    /// apps.created_at / SDProject.createdAt。履歴表示用。
    let createdAt: Date
    /// Discover 新着順ソートキー。user が編集画面で「更新を公開」を押した時に now() に更新される。
    /// 通常編集では更新されない (apps.last_bumped_at、新規登録時は created_at と同値)。
    let lastBumpedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        iconInitials: String,
        iconColor: ColorRGB = ColorRGB(red: 0.2, green: 0.25, blue: 0.4),
        iconUrl: String? = nil,
        platform: ProjectPlatform = .ios,
        status: ProjectStatus = .published,
        storeURL: String? = nil,
        githubURL: String? = nil,
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        authorAvatarUrl: String? = nil,
        screenshotColors: [ColorRGB] = [],
        averageRating: Double = 0,
        reviewCount: Int = 0,
        likes: Int = 0,
        tags: [String] = [],
        createdAt: Date = Date(),
        lastBumpedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconInitials = iconInitials
        self.iconColor = iconColor
        self.iconUrl = iconUrl
        self.platform = platform
        self.status = status
        self.storeURL = storeURL
        self.githubURL = githubURL
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.authorAvatarUrl = authorAvatarUrl
        self.screenshotColors = screenshotColors
        self.averageRating = averageRating
        self.reviewCount = reviewCount
        self.likes = likes
        self.tags = tags
        self.createdAt = createdAt
        self.lastBumpedAt = lastBumpedAt ?? createdAt
    }
}

enum ProjectPlatform: String, CaseIterable {
    case ios = "iOS"
    case android = "Android"
    case web = "Web"
    case other = "その他"

    var iconName: String {
        switch self {
        case .ios: return "apple.logo"
        case .android: return "android"
        case .web: return "globe"
        case .other: return "desktopcomputer"
        }
    }
}

enum ProjectStatus: String, CaseIterable {
    case draft = "下書き"
    case published = "公開"
    case archived = "アーカイブ"
}
