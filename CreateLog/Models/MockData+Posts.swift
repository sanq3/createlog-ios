import Foundation

#if DEBUG
extension MockData {
    static let posts: [Post] = [
        Post(
            name: "田中ゆうき",
            handle: "tanaka_dev",
            status: .coding,
            createdAt: date(minutesAgo: 120),
            workMinutes: 200,
            content: "SwiftUIのアニメーション、やっと理解できてきた。matchedGeometryEffectが最高すぎる #SwiftUI #個人開発",
            likes: 24,
            reposts: 5,
            comments: 3
        ),
        Post(
            name: "Emily Chen",
            handle: "emily_codes",
            status: .online,
            createdAt: date(minutesAgo: 240),
            workMinutes: 345,
            content: "Just shipped my first Flutter app! The feeling of seeing your creation on the App Store is unreal. 6 months of late nights finally paid off.",
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
            status: .offline,
            createdAt: date(minutesAgo: 360),
            workMinutes: 70,
            content: "初心者だけど、毎日30分でもコード書くようにしてる。今日で連続14日目。小さい積み重ねが大事だと信じてる #プログラミング初心者",
            likes: 142,
            reposts: 15,
            comments: 7
        ),
        Post(
            name: "Alex Kim",
            handle: "alexkim",
            status: .coding,
            createdAt: date(minutesAgo: 480),
            workMinutes: 450,
            content: "Working on a new design system for my SaaS. Dark mode palette is finally looking right.",
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
            status: .online,
            createdAt: date(minutesAgo: 600),
            workMinutes: 130,
            content: "Rustの勉強を始めた。所有権の概念が面白い。TypeScriptとは全然違うけど、理解できると気持ちいい",
            likes: 56,
            reposts: 3,
            comments: 8
        ),
        Post(
            name: "Maria Santos",
            handle: "maria_dev",
            status: .offline,
            createdAt: date(minutesAgo: 720),
            workMinutes: 240,
            content: "ポートフォリオサイト完成した！制作過程のタイムラプスも撮ったので見てほしい",
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
            status: .coding,
            createdAt: date(minutesAgo: 840),
            workMinutes: 375,
            content: "Docker Composeで開発環境を整えた。もう二度と「自分の環境では動く」とは言わない #Docker #インフラ",
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
            status: .offline,
            createdAt: date(minutesAgo: 960),
            workMinutes: 105,
            content: "Code review is an art form. Learning to give constructive feedback without being harsh is a skill worth developing",
            likes: 245,
            reposts: 31,
            comments: 19
        ),
        Post(
            name: "鈴木一郎",
            handle: "suzuki_dev",
            status: .coding,
            createdAt: date(minutesAgo: 1080),
            workMinutes: 290,
            content: "SwiftUIでカスタムチャートを実装中。Chartsフレームワーク使わずにやってみたら意外とできる",
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
#endif
