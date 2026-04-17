import Foundation

#if DEBUG
extension MockData {
    static let currentUser = User(
        name: "山田太郎",
        handle: "yamada_dev",
        bio: "iOS Developer / 個人開発が好き",
        status: .coding,
        followerCount: 234,
        followingCount: 156,
        totalHours: 1247,

        projectCount: 3,
        reviewCount: 12,
        trustScore: 4.8,
        links: [
            UserLink(type: .github, url: "https://github.com/yamada", label: "GitHub"),
            UserLink(type: .twitter, url: "https://x.com/yamada_dev", label: "X"),
            UserLink(type: .website, url: "https://yamada.dev", label: "yamada.dev"),
        ],
        occupation: "iOSエンジニア",
        experienceLevel: .threeToFive,
        skills: ["Swift", "SwiftUI", "UIKit", "Combine", "Core Data", "Firebase", "Supabase", "Git"],
        interests: ["iOS", "onboarding.role.soloDev", "UI/UX", "Swift"]
    )

    static let users: [User] = [
        User(
            name: "田中ゆうき",
            handle: "tanaka_dev",
            bio: "SwiftUI大好きエンジニア / 個人開発3年目",
            status: .coding,
            followerCount: 1205,
            followingCount: 342,
            isFollowing: true,
            totalHours: 3420,

            projectCount: 5,
            reviewCount: 28,
            trustScore: 4.9,
            occupation: "iOSエンジニア",
            experienceLevel: .threeToFive,
            skills: ["Swift", "SwiftUI", "Combine", "Core Data", "CloudKit"],
            interests: ["iOS", "onboarding.role.soloDev", "OSS"]
        ),
        User(
            name: "Emily Chen",
            handle: "emily_codes",
            bio: "Flutter & iOS dev. Building cool stuff.",
            status: .online,
            followerCount: 892,
            followingCount: 201,
            isFollowing: true,
            totalHours: 2100,

            projectCount: 4,
            reviewCount: 15,
            trustScore: 4.7,
            occupation: "モバイルエンジニア",
            experienceLevel: .threeToFive,
            skills: ["Flutter", "Dart", "Swift", "Firebase", "Figma"],
            interests: ["モバイル", "UI/UX", "クロスプラットフォーム"]
        ),
        User(
            name: "佐藤健太",
            handle: "sato_k",
            bio: "プログラミング初心者 / 毎日30分コーディング中",
            status: .offline,
            followerCount: 156,
            followingCount: 89,
            isFollowing: false,
            totalHours: 180,
    
            projectCount: 1,
            reviewCount: 3,
            trustScore: 5.0,
            occupation: "onboarding.role.student",
            experienceLevel: .lessThanOne,
            skills: ["Python", "SwiftUI"],
            interests: ["category.learn", "iOS", "AI"]
        ),
        User(
            name: "Alex Kim",
            handle: "alexkim",
            bio: "Full-stack engineer. React + Node.js + Supabase.",
            status: .coding,
            followerCount: 2340,
            followingCount: 567,
            isFollowing: false,
            totalHours: 5600,

            projectCount: 8,
            reviewCount: 45,
            trustScore: 4.6,
            occupation: "フルスタックエンジニア",
            experienceLevel: .fiveToTen,
            skills: ["React", "TypeScript", "Node.js", "Supabase", "PostgreSQL", "Docker", "AWS"],
            interests: ["Web", "SaaS", "インフラ", "OSS"]
        ),
        User(
            name: "高橋リョウ",
            handle: "ryo_codes",
            bio: "インフラエンジニア / Docker / Kubernetes",
            status: .coding,
            followerCount: 567,
            followingCount: 234,
            isFollowing: true,
            totalHours: 4200,

            projectCount: 3,
            reviewCount: 19,
            trustScore: 4.8,
            occupation: "インフラエンジニア",
            experienceLevel: .fiveToTen,
            skills: ["Docker", "Kubernetes", "Terraform", "AWS", "Go", "Linux"],
            interests: ["インフラ", "DevOps", "SRE"]
        ),
        User(
            name: "Maria Santos",
            handle: "maria_dev",
            bio: "Web designer & frontend developer",
            status: .offline,
            followerCount: 445,
            followingCount: 178,
            isFollowing: false,
            totalHours: 1890,

            projectCount: 6,
            reviewCount: 8,
            trustScore: 4.5,
            occupation: "フロントエンドエンジニア",
            experienceLevel: .threeToFive,
            skills: ["React", "Next.js", "TypeScript", "Figma", "Tailwind CSS"],
            interests: ["Web", "onboarding.role.design", "onboarding.role.soloDev"]
        ),
    ]
}

#endif
