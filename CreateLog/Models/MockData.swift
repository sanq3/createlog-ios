import SwiftUI

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
        ),
        PostData(
            name: "Yuki Tanaka",
            handle: "yuki_t",
            initials: "Y",
            status: .online,
            workTime: "2h 10m",
            content: "Rustの勉強を始めた。所有権の概念が面白い。TypeScriptとは全然違うけど、理解できると気持ちいい",
            timeAgo: "10h",
            likes: 56,
            reposts: 3,
            comments: 8
        ),
        PostData(
            name: "Maria Santos",
            handle: "maria_dev",
            initials: "M",
            status: .offline,
            workTime: "4h 00m",
            content: "Finally deployed my portfolio site. Next.js + Vercel is such a smooth combo. Link in bio if anyone wants to check it out",
            timeAgo: "12h",
            likes: 73,
            reposts: 11,
            comments: 5
        ),
        PostData(
            name: "高橋リョウ",
            handle: "ryo_codes",
            initials: "高",
            status: .coding,
            workTime: "6h 15m",
            content: "Docker Composeで開発環境を整えた。もう二度と「自分の環境では動く」とは言わない #Docker #インフラ",
            timeAgo: "14h",
            likes: 198,
            reposts: 22,
            comments: 14
        ),
        PostData(
            name: "Jake Wilson",
            handle: "jake_w",
            initials: "J",
            status: .offline,
            workTime: "1h 45m",
            content: "Code review is an art form. Learning to give constructive feedback without being harsh is a skill worth developing",
            timeAgo: "16h",
            likes: 245,
            reposts: 31,
            comments: 19
        )
    ]

    static let weeklyHours: [(day: String, hours: Double)] = [
        ("月", 3.2), ("火", 4.8), ("水", 3.5),
        ("木", 6.2), ("金", 5.1), ("土", 2.8), ("日", 4.5)
    ]

    static let categoryItems: [CategoryItem] = [
        CategoryItem(name: "iOS開発", hours: 12.5, percentage: 44),
        CategoryItem(name: "Web開発", hours: 8.25, percentage: 29),
        CategoryItem(name: "学習", hours: 5.0, percentage: 18),
        CategoryItem(name: "デザイン", hours: 2.75, percentage: 9)
    ]

    static let discoverItems: [DiscoverItem] = [
        DiscoverItem(
            type: .project, size: .tall,
            title: "Tempo",
            subtitle: "SwiftUIで作った習慣トラッカー",
            authorName: "田中ゆうき", authorInitials: "田",
            color: Color(red: 0.2, green: 0.25, blue: 0.45),
            iconName: "hammer.fill",
            metric: "182"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "SwiftUIで作るカスタムチャート",
            subtitle: "Charts不要の実装法",
            authorName: "佐藤健太", authorInitials: "佐",
            color: Color(red: 0.15, green: 0.2, blue: 0.3),
            iconName: "doc.text.fill",
            metric: "324"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Flutter vs SwiftUI 2026",
            subtitle: "12:34",
            authorName: "Emily Chen", authorInitials: "E",
            color: Color(red: 0.3, green: 0.18, blue: 0.25),
            iconName: "play.fill",
            metric: "1.2K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "async/await エラーハンドリング",
            subtitle: "Swift Concurrency",
            authorName: "高橋リョウ", authorInitials: "高",
            color: Color(red: 0.12, green: 0.18, blue: 0.22),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "89"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "FocusFlow",
            subtitle: "集中タイマーを個人開発中",
            authorName: "Alex Kim", authorInitials: "A",
            color: Color(red: 0.25, green: 0.15, blue: 0.35),
            iconName: "hammer.fill",
            metric: "67"
        ),
        DiscoverItem(
            type: .article, size: .tall,
            title: "個人開発で月10万円稼ぐまでの全記録",
            subtitle: "収益化の実体験",
            authorName: "Maria Santos", authorInitials: "M",
            color: Color(red: 0.18, green: 0.22, blue: 0.18),
            iconName: "doc.text.fill",
            metric: "2.1K"
        ),
        DiscoverItem(
            type: .video, size: .tall,
            title: "0からiOSアプリをリリースするまで",
            subtitle: "45:12",
            authorName: "Jake Wilson", authorInitials: "J",
            color: Color(red: 0.28, green: 0.15, blue: 0.15),
            iconName: "play.fill",
            metric: "5.6K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "matchedGeometryEffect 実践パターン",
            subtitle: "SwiftUI Animation",
            authorName: "鈴木一郎", authorInitials: "鈴",
            color: Color(red: 0.1, green: 0.15, blue: 0.2),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "156"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "CodeLog",
            subtitle: "開発記録を残すアプリを作ってます",
            authorName: "Yuki Tanaka", authorInitials: "Y",
            color: Color(red: 0.2, green: 0.2, blue: 0.35),
            iconName: "hammer.fill",
            metric: "93"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "Supabase認証完全ガイド",
            subtitle: "SwiftUI + Auth",
            authorName: "田中ゆうき", authorInitials: "田",
            color: Color(red: 0.15, green: 0.25, blue: 0.2),
            iconName: "doc.text.fill",
            metric: "890"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Rust入門 ライブコーディング",
            subtitle: "1:23:45",
            authorName: "高橋リョウ", authorInitials: "高",
            color: Color(red: 0.22, green: 0.12, blue: 0.18),
            iconName: "play.fill",
            metric: "3.4K"
        ),
        DiscoverItem(
            type: .project, size: .tall,
            title: "DevBoard",
            subtitle: "React + Supabaseでダッシュボード開発中",
            authorName: "Alex Kim", authorInitials: "A",
            color: Color(red: 0.15, green: 0.2, blue: 0.32),
            iconName: "hammer.fill",
            metric: "241"
        ),
    ]

    static let notifications: [NotificationItem] = [
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "田中", message: "があなたの投稿にいいねしました", time: "3分前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "Emily", message: "があなたをフォローしました", time: "1時間前"),
        NotificationItem(icon: "arrow.2.squarepath", iconColor: .clSuccess, actor: "佐藤", message: "があなたの投稿をリポストしました", time: "3時間前"),
        NotificationItem(icon: "heart.fill", iconColor: .clError, actor: "yuki", message: "が記録に反応しました", time: "5時間前"),
        NotificationItem(icon: "person.fill.badge.plus", iconColor: .clRecording, actor: "鈴木", message: "があなたをフォローしました", time: "昨日"),
    ]
}
