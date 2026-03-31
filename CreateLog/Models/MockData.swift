import Foundation

struct WeeklyStackedEntry: Identifiable {
    let id = UUID()
    let day: String
    let category: String
    let hours: Double
}

enum MockData {
    static let posts: [Post] = [
        Post(
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
        Post(
            name: "Emily Chen",
            handle: "emily_codes",
            initials: "E",
            status: .online,
            workTime: "5h 45m",
            content: "Just shipped my first Flutter app! The feeling of seeing your creation on the App Store is unreal. 6 months of late nights finally paid off.",
            timeAgo: "4h",
            likes: 89,
            reposts: 8,
            comments: 12,
            media: .images([
                PostImage(placeholderColor: ColorRGB(red: 0.15, green: 0.25, blue: 0.4), aspectRatio: 16 / 9)
            ])
        ),
        Post(
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
        Post(
            name: "Alex Kim",
            handle: "alexkim",
            initials: "A",
            status: .coding,
            workTime: "7h 30m",
            content: "Working on a new design system for my SaaS. Dark mode palette is finally looking right.",
            timeAgo: "8h",
            likes: 31,
            reposts: 2,
            comments: 4,
            media: .images([
                PostImage(placeholderColor: ColorRGB(red: 0.12, green: 0.12, blue: 0.2), aspectRatio: 1),
                PostImage(placeholderColor: ColorRGB(red: 0.2, green: 0.15, blue: 0.25), aspectRatio: 1)
            ])
        ),
        Post(
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
        Post(
            name: "Maria Santos",
            handle: "maria_dev",
            initials: "M",
            status: .offline,
            workTime: "4h 00m",
            content: "ポートフォリオサイト完成した！制作過程のタイムラプスも撮ったので見てほしい",
            timeAgo: "12h",
            likes: 73,
            reposts: 11,
            comments: 5,
            media: .video(PostVideo(
                placeholderColor: ColorRGB(red: 0.18, green: 0.22, blue: 0.18),
                duration: "2:34",
                aspectRatio: 16 / 9
            ))
        ),
        Post(
            name: "高橋リョウ",
            handle: "ryo_codes",
            initials: "高",
            status: .coding,
            workTime: "6h 15m",
            content: "Docker Composeで開発環境を整えた。もう二度と「自分の環境では動く」とは言わない #Docker #インフラ",
            timeAgo: "14h",
            likes: 198,
            reposts: 22,
            comments: 14,
            media: .images([
                PostImage(placeholderColor: ColorRGB(red: 0.1, green: 0.15, blue: 0.2), aspectRatio: 4 / 3),
                PostImage(placeholderColor: ColorRGB(red: 0.15, green: 0.1, blue: 0.2), aspectRatio: 4 / 3),
                PostImage(placeholderColor: ColorRGB(red: 0.2, green: 0.15, blue: 0.15), aspectRatio: 4 / 3)
            ])
        ),
        Post(
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
        ),
        Post(
            name: "鈴木一郎",
            handle: "suzuki_dev",
            initials: "鈴",
            status: .coding,
            workTime: "4h 50m",
            content: "SwiftUIでカスタムチャートを実装中。Chartsフレームワーク使わずにやってみたら意外とできる",
            timeAgo: "18h",
            likes: 67,
            reposts: 4,
            comments: 6,
            media: .images([
                PostImage(placeholderColor: ColorRGB(red: 0.22, green: 0.18, blue: 0.35), aspectRatio: 1),
                PostImage(placeholderColor: ColorRGB(red: 0.18, green: 0.28, blue: 0.22), aspectRatio: 1),
                PostImage(placeholderColor: ColorRGB(red: 0.28, green: 0.15, blue: 0.2), aspectRatio: 1),
                PostImage(placeholderColor: ColorRGB(red: 0.15, green: 0.2, blue: 0.3), aspectRatio: 1)
            ])
        )
    ]

    static let weeklyHours: [(day: String, hours: Double)] = [
        ("月", 3.2), ("火", 4.8), ("水", 3.5),
        ("木", 6.2), ("金", 5.1), ("土", 2.8), ("日", 4.5)
    ]

    static let weeklyStackedHours: [WeeklyStackedEntry] = [
        // 月 (3.2h)
        WeeklyStackedEntry(day: "月", category: "iOS開発", hours: 1.5),
        WeeklyStackedEntry(day: "月", category: "学習", hours: 1.0),
        WeeklyStackedEntry(day: "月", category: "バグ修正", hours: 0.7),
        // 火 (4.8h)
        WeeklyStackedEntry(day: "火", category: "iOS開発", hours: 2.5),
        WeeklyStackedEntry(day: "火", category: "学習", hours: 0.8),
        WeeklyStackedEntry(day: "火", category: "Web開発", hours: 1.5),
        // 水 (3.5h)
        WeeklyStackedEntry(day: "水", category: "iOS開発", hours: 1.8),
        WeeklyStackedEntry(day: "水", category: "バグ修正", hours: 1.0),
        WeeklyStackedEntry(day: "水", category: "デザイン", hours: 0.7),
        // 木 (6.2h)
        WeeklyStackedEntry(day: "木", category: "iOS開発", hours: 3.0),
        WeeklyStackedEntry(day: "木", category: "学習", hours: 1.5),
        WeeklyStackedEntry(day: "木", category: "Web開発", hours: 1.2),
        WeeklyStackedEntry(day: "木", category: "デザイン", hours: 0.5),
        // 金 (5.1h)
        WeeklyStackedEntry(day: "金", category: "iOS開発", hours: 2.8),
        WeeklyStackedEntry(day: "金", category: "学習", hours: 1.0),
        WeeklyStackedEntry(day: "金", category: "バグ修正", hours: 1.3),
        // 土 (2.8h)
        WeeklyStackedEntry(day: "土", category: "iOS開発", hours: 1.3),
        WeeklyStackedEntry(day: "土", category: "学習", hours: 1.5),
        // 日 (4.5h)
        WeeklyStackedEntry(day: "日", category: "iOS開発", hours: 2.5),
        WeeklyStackedEntry(day: "日", category: "学習", hours: 0.5),
        WeeklyStackedEntry(day: "日", category: "Web開発", hours: 1.0),
        WeeklyStackedEntry(day: "日", category: "デザイン", hours: 0.5),
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
            placeholderColor: ColorRGB(red: 0.2, green: 0.25, blue: 0.45),
            iconName: "hammer.fill",
            metric: "182"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "SwiftUIで作るカスタムチャート",
            subtitle: "Charts不要の実装法",
            authorName: "佐藤健太", authorInitials: "佐",
            placeholderColor: ColorRGB(red: 0.15, green: 0.2, blue: 0.3),
            iconName: "doc.text.fill",
            metric: "324"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Flutter vs SwiftUI 2026",
            subtitle: "12:34",
            authorName: "Emily Chen", authorInitials: "E",
            placeholderColor: ColorRGB(red: 0.3, green: 0.18, blue: 0.25),
            iconName: "play.fill",
            metric: "1.2K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "async/await エラーハンドリング",
            subtitle: "Swift Concurrency",
            authorName: "高橋リョウ", authorInitials: "高",
            placeholderColor: ColorRGB(red: 0.12, green: 0.18, blue: 0.22),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "89"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "FocusFlow",
            subtitle: "集中タイマーを個人開発中",
            authorName: "Alex Kim", authorInitials: "A",
            placeholderColor: ColorRGB(red: 0.25, green: 0.15, blue: 0.35),
            iconName: "hammer.fill",
            metric: "67"
        ),
        DiscoverItem(
            type: .article, size: .tall,
            title: "個人開発で月10万円稼ぐまでの全記録",
            subtitle: "収益化の実体験",
            authorName: "Maria Santos", authorInitials: "M",
            placeholderColor: ColorRGB(red: 0.18, green: 0.22, blue: 0.18),
            iconName: "doc.text.fill",
            metric: "2.1K"
        ),
        DiscoverItem(
            type: .video, size: .tall,
            title: "0からiOSアプリをリリースするまで",
            subtitle: "45:12",
            authorName: "Jake Wilson", authorInitials: "J",
            placeholderColor: ColorRGB(red: 0.28, green: 0.15, blue: 0.15),
            iconName: "play.fill",
            metric: "5.6K"
        ),
        DiscoverItem(
            type: .codeSnippet, size: .small,
            title: "matchedGeometryEffect 実践パターン",
            subtitle: "SwiftUI Animation",
            authorName: "鈴木一郎", authorInitials: "鈴",
            placeholderColor: ColorRGB(red: 0.1, green: 0.15, blue: 0.2),
            iconName: "chevron.left.forwardslash.chevron.right",
            metric: "156"
        ),
        DiscoverItem(
            type: .project, size: .small,
            title: "CodeLog",
            subtitle: "開発記録を残すアプリを作ってます",
            authorName: "Yuki Tanaka", authorInitials: "Y",
            placeholderColor: ColorRGB(red: 0.2, green: 0.2, blue: 0.35),
            iconName: "hammer.fill",
            metric: "93"
        ),
        DiscoverItem(
            type: .article, size: .small,
            title: "Supabase認証完全ガイド",
            subtitle: "SwiftUI + Auth",
            authorName: "田中ゆうき", authorInitials: "田",
            placeholderColor: ColorRGB(red: 0.15, green: 0.25, blue: 0.2),
            iconName: "doc.text.fill",
            metric: "890"
        ),
        DiscoverItem(
            type: .video, size: .small,
            title: "Rust入門 ライブコーディング",
            subtitle: "1:23:45",
            authorName: "高橋リョウ", authorInitials: "高",
            placeholderColor: ColorRGB(red: 0.22, green: 0.12, blue: 0.18),
            iconName: "play.fill",
            metric: "3.4K"
        ),
        DiscoverItem(
            type: .project, size: .tall,
            title: "DevBoard",
            subtitle: "React + Supabaseでダッシュボード開発中",
            authorName: "Alex Kim", authorInitials: "A",
            placeholderColor: ColorRGB(red: 0.15, green: 0.2, blue: 0.32),
            iconName: "hammer.fill",
            metric: "241"
        ),
    ]

    // MARK: - Users

    static let currentUser = User(
        name: "山田太郎",
        handle: "yamada_dev",
        initials: "山",
        bio: "iOS Developer / 個人開発が好き",
        status: .coding,
        followerCount: 234,
        followingCount: 156,
        totalHours: 1247,
        streak: 14,
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
        interests: ["iOS", "個人開発", "UI/UX", "Swift"]
    )

    static let users: [User] = [
        User(
            name: "田中ゆうき",
            handle: "tanaka_dev",
            initials: "田",
            bio: "SwiftUI大好きエンジニア / 個人開発3年目",
            status: .coding,
            followerCount: 1205,
            followingCount: 342,
            isFollowing: true,
            totalHours: 3420,
            streak: 42,
            projectCount: 5,
            reviewCount: 28,
            trustScore: 4.9,
            occupation: "iOSエンジニア",
            experienceLevel: .threeToFive,
            skills: ["Swift", "SwiftUI", "Combine", "Core Data", "CloudKit"],
            interests: ["iOS", "個人開発", "OSS"]
        ),
        User(
            name: "Emily Chen",
            handle: "emily_codes",
            initials: "E",
            bio: "Flutter & iOS dev. Building cool stuff.",
            status: .online,
            followerCount: 892,
            followingCount: 201,
            isFollowing: true,
            totalHours: 2100,
            streak: 7,
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
            initials: "佐",
            bio: "プログラミング初心者 / 毎日30分コーディング中",
            status: .offline,
            followerCount: 156,
            followingCount: 89,
            isFollowing: false,
            totalHours: 180,
            streak: 14,
            projectCount: 1,
            reviewCount: 3,
            trustScore: 5.0,
            occupation: "学生",
            experienceLevel: .lessThanOne,
            skills: ["Python", "SwiftUI"],
            interests: ["学習", "iOS", "AI"]
        ),
        User(
            name: "Alex Kim",
            handle: "alexkim",
            initials: "A",
            bio: "Full-stack engineer. React + Node.js + Supabase.",
            status: .coding,
            followerCount: 2340,
            followingCount: 567,
            isFollowing: false,
            totalHours: 5600,
            streak: 89,
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
            initials: "高",
            bio: "インフラエンジニア / Docker / Kubernetes",
            status: .coding,
            followerCount: 567,
            followingCount: 234,
            isFollowing: true,
            totalHours: 4200,
            streak: 21,
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
            initials: "M",
            bio: "Web designer & frontend developer",
            status: .offline,
            followerCount: 445,
            followingCount: 178,
            isFollowing: false,
            totalHours: 1890,
            streak: 5,
            projectCount: 6,
            reviewCount: 8,
            trustScore: 4.5,
            occupation: "フロントエンドエンジニア",
            experienceLevel: .threeToFive,
            skills: ["React", "Next.js", "TypeScript", "Figma", "Tailwind CSS"],
            interests: ["Web", "デザイン", "個人開発"]
        ),
    ]

    // MARK: - Articles

    static let articles: [Article] = [
        Article(
            title: "SwiftUIで作るカスタムチャート完全ガイド",
            body: """
            Swift Chartsフレームワークを使わずに、SwiftUIだけでカスタムチャートを実装する方法を解説します。

            ## なぜカスタムチャート？

            Swift Chartsは便利ですが、デザインの自由度に制限があります。ブランドカラーや独自のインタラクションを実装したい場合、カスタム実装が必要になることがあります。

            ## Path を使った描画

            SwiftUIのPath APIを使えば、任意の形状を描画できます。棒グラフ、折れ線グラフ、円グラフなど、あらゆるチャートを実装可能です。

            ## アニメーション

            `.trim(from:to:)` モディファイアと `withAnimation` を組み合わせることで、美しいアニメーション付きのチャートを作れます。

            ## まとめ

            カスタムチャートの実装は一見大変に見えますが、基本的なPath操作を理解すれば意外とシンプルです。
            """,
            authorName: "佐藤健太",
            authorHandle: "sato_k",
            authorInitials: "佐",
            coverColor: ColorRGB(red: 0.15, green: 0.2, blue: 0.3),
            readingTime: 8,
            likes: 324,
            comments: 12,
            tags: ["SwiftUI", "iOS", "チャート"]
        ),
        Article(
            title: "個人開発で月10万円稼ぐまでの全記録",
            body: """
            個人開発を始めて2年。ようやく月10万円の収益を達成しました。その道のりを包み隠さず共有します。

            ## 最初の半年: 収益ゼロ

            最初に作ったアプリは全くダウンロードされませんでした。マーケティングの重要性を痛感しました。

            ## 転機

            X（旧Twitter）での発信を始めたことが転機でした。開発過程を共有することでフォロワーが増え、アプリのダウンロード数も伸びました。

            ## 収益化のポイント

            広告とサブスクリプションの2本柱。広告だけでは限界があるので、プレミアム機能を用意することが重要です。
            """,
            authorName: "Maria Santos",
            authorHandle: "maria_dev",
            authorInitials: "M",
            coverColor: ColorRGB(red: 0.18, green: 0.22, blue: 0.18),
            readingTime: 12,
            likes: 2100,
            comments: 45,
            tags: ["個人開発", "収益化", "マーケティング"]
        ),
    ]

    // MARK: - Projects

    static let projects: [Project] = [
        Project(
            name: "Tempo",
            description: "SwiftUIで作った習慣トラッカー。毎日の習慣を記録して、継続率をビジュアルで確認できます。ヒートマップ表示やリマインダー機能付き。",
            iconInitials: "T",
            iconColor: ColorRGB(red: 0.2, green: 0.25, blue: 0.45),
            platform: .ios,
            storeURL: "https://apps.apple.com/app/tempo",
            authorName: "田中ゆうき",
            authorHandle: "tanaka_dev",
            authorInitials: "田",
            screenshotColors: [
                ColorRGB(red: 0.15, green: 0.2, blue: 0.35),
                ColorRGB(red: 0.2, green: 0.15, blue: 0.3),
                ColorRGB(red: 0.1, green: 0.25, blue: 0.3),
            ],
            averageRating: 4.5,
            reviewCount: 12,
            likes: 182,
            tags: ["SwiftUI", "iOS", "習慣"]
        ),
        Project(
            name: "FocusFlow",
            description: "集中タイマーアプリ。ポモドーロテクニックベースで、作業と休憩のサイクルを管理。統計機能で1週間の集中時間を可視化。",
            iconInitials: "F",
            iconColor: ColorRGB(red: 0.25, green: 0.15, blue: 0.35),
            platform: .ios,
            authorName: "Alex Kim",
            authorHandle: "alexkim",
            authorInitials: "A",
            screenshotColors: [
                ColorRGB(red: 0.2, green: 0.12, blue: 0.28),
                ColorRGB(red: 0.15, green: 0.18, blue: 0.3),
            ],
            averageRating: 4.2,
            reviewCount: 8,
            likes: 67,
            tags: ["ポモドーロ", "生産性", "タイマー"]
        ),
        Project(
            name: "DevBoard",
            description: "React + Supabaseで作ったダッシュボード。GitHub APIと連携してリポジトリの活動を可視化。チーム開発の進捗管理にも使える。",
            iconInitials: "D",
            iconColor: ColorRGB(red: 0.15, green: 0.2, blue: 0.32),
            platform: .web,
            githubURL: "https://github.com/alexkim/devboard",
            authorName: "Alex Kim",
            authorHandle: "alexkim",
            authorInitials: "A",
            screenshotColors: [
                ColorRGB(red: 0.12, green: 0.18, blue: 0.25),
                ColorRGB(red: 0.18, green: 0.15, blue: 0.22),
                ColorRGB(red: 0.1, green: 0.2, blue: 0.2),
            ],
            averageRating: 4.0,
            reviewCount: 5,
            likes: 241,
            tags: ["React", "Supabase", "ダッシュボード"]
        ),
    ]

    // MARK: - Comments

    private static func date(minutesAgo minutes: Int) -> Date {
        Date().addingTimeInterval(-Double(minutes * 60))
    }

    static let comments: [Comment] = [
        Comment(
            authorName: "高橋リョウ",
            authorHandle: "ryo_codes",
            authorInitials: "高",
            text: "めっちゃわかる！matchedGeometryEffect使い始めたら戻れなくなるよね",
            timestamp: date(minutesAgo: 30),
            likes: 8,
            replies: [
                Comment(
                    authorName: "田中ゆうき",
                    authorHandle: "tanaka_dev",
                    authorInitials: "田",
                    text: "ほんとそれ。Hero animationが簡単に作れるのがすごい",
                    timestamp: date(minutesAgo: 25),
                    likes: 3
                ),
            ]
        ),
        Comment(
            authorName: "Emily Chen",
            authorHandle: "emily_codes",
            authorInitials: "E",
            text: "I've been using this in my latest project too! The API is so clean.",
            timestamp: date(minutesAgo: 120),
            likes: 5
        ),
        Comment(
            authorName: "佐藤健太",
            authorHandle: "sato_k",
            authorInitials: "佐",
            text: "初心者なんですけど、matchedGeometryEffectってどういう場面で使うんですか？",
            timestamp: date(minutesAgo: 180),
            likes: 2,
            replies: [
                Comment(
                    authorName: "田中ゆうき",
                    authorHandle: "tanaka_dev",
                    authorInitials: "田",
                    text: "画面遷移のときに要素がスムーズに移動するアニメーションを作れるよ。タブの切り替えとかカードの展開とか！",
                    timestamp: date(minutesAgo: 170),
                    likes: 6
                ),
                Comment(
                    authorName: "佐藤健太",
                    authorHandle: "sato_k",
                    authorInitials: "佐",
                    text: "なるほど！試してみます",
                    timestamp: date(minutesAgo: 160),
                    likes: 1
                ),
            ]
        ),
    ]

    // MARK: - Reviews

    static let reviews: [Review] = [
        Review(
            authorName: "Emily Chen",
            authorHandle: "emily_codes",
            authorInitials: "E",
            rating: 5,
            text: "UIがとても綺麗で使いやすい。毎日の習慣管理がこれのおかげで続いてる。",
            timestamp: date(minutesAgo: 4320),
            developerReply: "ありがとうございます！今後もUI改善を続けていきます。"
        ),
        Review(
            authorName: "佐藤健太",
            authorHandle: "sato_k",
            authorInitials: "佐",
            rating: 4,
            text: "全体的にいいけど、ウィジェット対応してほしい。",
            timestamp: date(minutesAgo: 10080)
        ),
        Review(
            authorName: "Alex Kim",
            authorHandle: "alexkim",
            authorInitials: "A",
            rating: 5,
            text: "Great design and smooth animations. Would love to see a web version!",
            timestamp: date(minutesAgo: 20160),
            developerReply: "Thanks! Web version is in the roadmap."
        ),
    ]

    // MARK: - Logs

    static let todayLogs: [LogEntry] = [
        LogEntry(
            title: "UI実装",
            categoryName: "iOS開発",
            startHour: 8.0,
            endHour: 10.5
        ),
        LogEntry(
            title: "Swift Concurrency勉強",
            categoryName: "学習",
            startHour: 11.0,
            endHour: 12.0,
            isAutoTracked: true
        ),
        LogEntry(
            title: "API不具合の調査",
            categoryName: "バグ修正",
            startHour: 13.5,
            endHour: 14.75
        ),
    ]

    // MARK: - Notifications

    static let notifications: [NotificationItem] = [
        // 未読 (新着セクション)
        NotificationItem(
            type: .like,
            primaryActor: "田中ゆうき",
            groupedActors: ["Emily Chen", "佐藤健太"],
            message: "があなたの投稿にいいねしました",
            timestamp: date(minutesAgo: 3),
            contentPreview: "SwiftUIのアニメーション、やっと理解できてきた..."
        ),
        NotificationItem(
            type: .follow,
            primaryActor: "Alex Kim",
            message: "があなたをフォローしました",
            timestamp: date(minutesAgo: 15)
        ),
        NotificationItem(
            type: .comment,
            primaryActor: "高橋リョウ",
            message: "があなたの投稿にコメントしました",
            timestamp: date(minutesAgo: 42),
            contentPreview: "自分もmatchedGeometryEffect使ってます！"
        ),

        // 既読 - 今日
        NotificationItem(
            type: .like,
            primaryActor: "Maria Santos",
            groupedActors: ["Jake Wilson", "鈴木一郎", "Yuki Tanaka", "高橋リョウ"],
            message: "があなたの記録にいいねしました",
            timestamp: date(minutesAgo: 180),
            isRead: true,
            contentPreview: "UI実装 - 3h 20m"
        ),
        NotificationItem(
            type: .repost,
            primaryActor: "Emily Chen",
            message: "があなたの投稿をリポストしました",
            timestamp: date(minutesAgo: 300),
            isRead: true,
            contentPreview: "Docker Composeで開発環境を整えた..."
        ),
        NotificationItem(
            type: .mention,
            primaryActor: "佐藤健太",
            message: "が投稿であなたをメンションしました",
            timestamp: date(minutesAgo: 420),
            isRead: true,
            contentPreview: "@you SwiftUIのチャート実装について質問..."
        ),
        NotificationItem(
            type: .system,
            primaryActor: "CreateLog",
            message: "今週の作業レポートが届きました",
            timestamp: date(minutesAgo: 600),
            isRead: true
        ),

        // 既読 - 今週
        NotificationItem(
            type: .follow,
            primaryActor: "鈴木一郎",
            groupedActors: ["Maria Santos"],
            message: "があなたをフォローしました",
            timestamp: date(minutesAgo: 2880),
            isRead: true
        ),
        NotificationItem(
            type: .like,
            primaryActor: "Jake Wilson",
            groupedActors: ["Alex Kim"],
            message: "があなたの記事にいいねしました",
            timestamp: date(minutesAgo: 4320),
            isRead: true,
            contentPreview: "個人開発で月10万円稼ぐまでの全記録"
        ),
        NotificationItem(
            type: .comment,
            primaryActor: "Yuki Tanaka",
            message: "があなたの記録にコメントしました",
            timestamp: date(minutesAgo: 5760),
            isRead: true,
            contentPreview: "Rust、自分も始めました!"
        ),
        NotificationItem(
            type: .system,
            primaryActor: "CreateLog",
            message: "連続記録が7日に達しました",
            timestamp: date(minutesAgo: 7200),
            isRead: true
        ),

        // 既読 - それ以前
        NotificationItem(
            type: .like,
            primaryActor: "田中ゆうき",
            groupedActors: ["佐藤健太", "Emily Chen", "高橋リョウ", "Maria Santos", "Jake Wilson", "鈴木一郎"],
            message: "があなたのプロジェクトにいいねしました",
            timestamp: date(minutesAgo: 14400),
            isRead: true,
            contentPreview: "Tempo - 習慣トラッカー"
        ),
        NotificationItem(
            type: .system,
            primaryActor: "CreateLog",
            message: "新機能「プロジェクトタイムライン」をリリースしました",
            timestamp: date(minutesAgo: 15000),
            isRead: true
        ),
        NotificationItem(
            type: .follow,
            primaryActor: "高橋リョウ",
            message: "があなたをフォローしました",
            timestamp: date(minutesAgo: 20160),
            isRead: true
        ),
        NotificationItem(
            type: .system,
            primaryActor: "CreateLog",
            message: "3月のメンテナンス: 3/30 02:00-04:00",
            timestamp: date(minutesAgo: 25000),
            isRead: true
        ),
    ]
}
