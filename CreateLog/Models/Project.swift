import Foundation

struct Project: Identifiable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let iconInitials: String
    let iconColor: ColorRGB
    let platform: ProjectPlatform
    let status: ProjectStatus
    let storeURL: String?
    let githubURL: String?
    let authorName: String
    let authorHandle: String
    let authorInitials: String
    let screenshotColors: [ColorRGB]
    let averageRating: Double
    let reviewCount: Int
    let likes: Int
    let tags: [String]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        iconInitials: String,
        iconColor: ColorRGB = ColorRGB(red: 0.2, green: 0.25, blue: 0.4),
        platform: ProjectPlatform = .ios,
        status: ProjectStatus = .published,
        storeURL: String? = nil,
        githubURL: String? = nil,
        authorName: String,
        authorHandle: String,
        authorInitials: String,
        screenshotColors: [ColorRGB] = [],
        averageRating: Double = 0,
        reviewCount: Int = 0,
        likes: Int = 0,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.iconInitials = iconInitials
        self.iconColor = iconColor
        self.platform = platform
        self.status = status
        self.storeURL = storeURL
        self.githubURL = githubURL
        self.authorName = authorName
        self.authorHandle = authorHandle
        self.authorInitials = authorInitials
        self.screenshotColors = screenshotColors
        self.averageRating = averageRating
        self.reviewCount = reviewCount
        self.likes = likes
        self.tags = tags
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
