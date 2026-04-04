import Foundation

extension MockData {
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
        ),
    ]
}
