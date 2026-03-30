import Foundation

struct User: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initials: String
    let bio: String
    let status: OnlineStatus
    let followerCount: Int
    let followingCount: Int
    var isFollowing: Bool
    let totalHours: Double
    let streak: Int
    let projectCount: Int
    let reviewCount: Int
    let trustScore: Double
    let links: [UserLink]

    init(
        name: String,
        handle: String,
        initials: String,
        bio: String = "",
        status: OnlineStatus = .offline,
        followerCount: Int = 0,
        followingCount: Int = 0,
        isFollowing: Bool = false,
        totalHours: Double = 0,
        streak: Int = 0,
        projectCount: Int = 0,
        reviewCount: Int = 0,
        trustScore: Double = 5.0,
        links: [UserLink] = []
    ) {
        self.name = name
        self.handle = handle
        self.initials = initials
        self.bio = bio
        self.status = status
        self.followerCount = followerCount
        self.followingCount = followingCount
        self.isFollowing = isFollowing
        self.totalHours = totalHours
        self.streak = streak
        self.projectCount = projectCount
        self.reviewCount = reviewCount
        self.trustScore = trustScore
        self.links = links
    }
}

struct UserLink: Identifiable {
    let id = UUID()
    let type: LinkType
    let url: String
    let label: String

    enum LinkType {
        case website
        case github
        case twitter
        case zenn
        case qiita
        case other
    }
}
