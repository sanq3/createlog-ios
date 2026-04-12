import Foundation

// MARK: - PostDTO → Post

extension Post {
    init(from dto: PostDTO) {
        self.init(
            id: dto.id,
            name: dto.authorDisplayName ?? "",
            handle: dto.authorHandle ?? "",
            status: .offline,
            createdAt: dto.createdAt,
            workMinutes: 0,
            content: dto.content,
            likes: dto.likesCount,
            reposts: dto.repostsCount,
            comments: dto.commentsCount,
            media: nil
        )
    }
}

// MARK: - NotificationDTO → NotificationItem

extension NotificationItem {
    init(from dto: NotificationDTO) {
        let type: NotificationType = switch dto.type {
        case "like": .like
        case "follow": .follow
        case "repost": .repost
        case "comment": .comment
        case "mention": .mention
        default: .system
        }

        self.init(
            id: dto.id,
            type: type,
            primaryActor: dto.actorDisplayName ?? dto.actorHandle ?? "someone",
            message: dto.message ?? "",
            timestamp: dto.createdAt,
            isRead: dto.isRead
        )
    }
}

// MARK: - ProfileDTO → User

extension User {
    init(from dto: ProfileDTO) {
        // T4-B: SNS 3 URL を UserLink 配列に変換 (empty は除外)
        var links: [UserLink] = []
        if let github = dto.githubUrl, !github.isEmpty {
            links.append(UserLink(type: .github, url: github, label: "GitHub"))
        }
        if let x = dto.xUrl, !x.isEmpty {
            links.append(UserLink(type: .twitter, url: x, label: "X"))
        }
        if let web = dto.websiteUrl, !web.isEmpty {
            links.append(UserLink(type: .website, url: web, label: "Website"))
        }

        self.init(
            id: dto.id,
            name: dto.displayName ?? "",
            handle: dto.handle ?? "",
            bio: dto.bio ?? "",
            followerCount: dto.followersCount,
            followingCount: dto.followingCount,
            links: links,
            occupation: dto.occupation ?? "",
            experienceLevel: ExperienceLevel(serverValue: dto.experienceYears)
        )
    }
}

extension ExperienceLevel {
    init(serverValue: String?) {
        switch serverValue {
        case "under_3_months", "three_to_six_months", "six_to_twelve_months":
            self = .lessThanOne
        case "one_to_two_years", "two_to_three_years":
            self = .oneToThree
        case "three_to_four_years", "four_to_five_years":
            self = .threeToFive
        case "over_five_years":
            self = .fiveToTen
        default:
            self = .lessThanOne
        }
    }

    /// ドメイン → サーバー値の逆変換。UI の粗い粒度を保存時にサーバー値に落とす。
    /// サーバー側の粒度の方が細かいため、UI の大分類の代表値を選ぶ。
    var serverValue: String {
        switch self {
        case .lessThanOne: "six_to_twelve_months"
        case .oneToThree: "one_to_two_years"
        case .threeToFive: "three_to_four_years"
        case .fiveToTen: "over_five_years"
        case .moreThanTen: "over_five_years"
        }
    }
}

// MARK: - AppDTO → Project

extension Project {
    init(from dto: AppDTO) {
        self.init(
            id: dto.id,
            name: dto.name,
            description: dto.description ?? "",
            iconInitials: String(dto.name.prefix(2)),
            platform: ProjectPlatform(serverValue: dto.platform),
            status: ProjectStatus(serverValue: dto.status),
            storeURL: dto.storeUrl,
            githubURL: dto.githubUrl,
            authorName: "",
            authorHandle: "",
            authorInitials: "",
            averageRating: dto.avgRating ?? 0,
            reviewCount: dto.reviewCount
        )
    }
}

extension ProjectPlatform {
    init(serverValue: String) {
        switch serverValue {
        case "ios": self = .ios
        case "android": self = .android
        case "web": self = .web
        default: self = .other
        }
    }
}

extension ProjectStatus {
    init(serverValue: String) {
        switch serverValue {
        case "draft": self = .draft
        case "published": self = .published
        case "archived": self = .archived
        default: self = .draft
        }
    }
}
