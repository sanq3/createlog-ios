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
    let occupation: String
    let experienceLevel: ExperienceLevel
    let skills: [String]
    let interests: [String]

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
        links: [UserLink] = [],
        occupation: String = "",
        experienceLevel: ExperienceLevel = .lessThanOne,
        skills: [String] = [],
        interests: [String] = []
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
        self.occupation = occupation
        self.experienceLevel = experienceLevel
        self.skills = skills
        self.interests = interests
    }
}

enum ExperienceLevel: String, CaseIterable, Sendable {
    case lessThanOne
    case oneToThree
    case threeToFive
    case fiveToTen
    case moreThanTen

    var label: String {
        switch self {
        case .lessThanOne: "1年未満"
        case .oneToThree: "1-3年"
        case .threeToFive: "3-5年"
        case .fiveToTen: "5-10年"
        case .moreThanTen: "10年以上"
        }
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

        var iconName: String {
            switch self {
            case .website: "globe"
            case .github: "chevron.left.forwardslash.chevron.right"
            case .twitter: "at"
            case .zenn: "doc.text"
            case .qiita: "doc.text"
            case .other: "link"
            }
        }
    }
}
