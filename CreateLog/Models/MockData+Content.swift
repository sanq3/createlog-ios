import Foundation

extension MockData {

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
}
