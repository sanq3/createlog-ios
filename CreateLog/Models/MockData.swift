import Foundation

#if DEBUG
enum MockData {

    // MARK: - Charts

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

    // MARK: - Discover

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

    // MARK: - Helpers

    static func date(minutesAgo minutes: Int) -> Date {
        Date().addingTimeInterval(-Double(minutes * 60))
    }

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

#endif
