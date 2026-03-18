import Foundation

enum MockData {
    static let posts: [PostData] = [
        PostData(
            name: "田中ゆうき",
            handle: "tanaka_dev",
            initials: "田",
            status: .coding,
            workTime: "3h 20m",
            content: "SwiftUIのアニメーション、やっと理解できてきた。matchedGeometryEffectが最高すぎる #SwiftUI #個人開発",
            timeAgo: "2h",
            likes: 24,
            reposts: 5,
            comments: 3
        ),
        PostData(
            name: "Emily Chen",
            handle: "emily_codes",
            initials: "E",
            status: .online,
            workTime: "5h 45m",
            content: "Just shipped my first Flutter app! The feeling of seeing your creation on the App Store is unreal. 6 months of late nights finally paid off.",
            timeAgo: "4h",
            likes: 89,
            reposts: 8,
            comments: 12
        ),
        PostData(
            name: "佐藤健太",
            handle: "sato_k",
            initials: "佐",
            status: .offline,
            workTime: "1h 10m",
            content: "初心者だけど、毎日30分でもコード書くようにしてる。今日で連続14日目。小さい積み重ねが大事だと信じてる #プログラミング初心者",
            timeAgo: "6h",
            likes: 142,
            reposts: 15,
            comments: 7
        ),
        PostData(
            name: "Alex Kim",
            handle: "alexkim",
            initials: "A",
            status: .coding,
            workTime: "7h 30m",
            content: "Working on a new design system for my SaaS. Trying to nail the dark mode color palette.",
            timeAgo: "8h",
            likes: 31,
            reposts: 2,
            comments: 4
        )
    ]

    static let weeklyHours: [(day: String, hours: Double)] = [
        ("月", 3.2), ("火", 4.8), ("水", 3.5),
        ("木", 6.2), ("金", 5.1), ("土", 2.8), ("日", 4.5)
    ]

    static let categories: [(name: String, hours: Double, color: String)] = [
        ("iOS開発", 12.5, "clAccent"),
        ("Web開発", 8.25, "clTextSecondary"),
        ("学習", 5.0, "clTextTertiary"),
        ("デザイン", 2.75, "clBorder")
    ]
}
