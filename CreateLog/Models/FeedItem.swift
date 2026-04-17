import Foundation

/// Discover masonry feed で使う、Post / Project 混合の表示単位。
/// AppRepository + PostRepository を並列 fetch し、createdAt DESC で merge sort する。
enum FeedItem: Identifiable, Sendable {
    case post(Post)
    case project(Project)

    var id: UUID {
        switch self {
        case .post(let post): return post.id
        case .project(let project): return project.id
        }
    }

    /// Discover 混合 feed のソートキー (effective 日時)。
    /// - Post: 作成日時 (編集での bump はしない方針)
    /// - Project: `lastBumpedAt` (user が「更新を公開」した時刻、新規登録時は created_at と同値)
    var createdAt: Date {
        switch self {
        case .post(let post): return post.createdAt
        case .project(let project): return project.lastBumpedAt
        }
    }

    /// 2 列 masonry での高さクラス。ビジュアル量 (media / icon / screenshot) と本文長で切替。
    var masonrySize: MasonryTileSize {
        switch self {
        case .post(let post):
            guard let media = post.media else {
                return post.content.count > 70 ? .tall : .small
            }
            switch media {
            case .images, .video: return .tall
            case .code: return .small
            }
        case .project(let project):
            let hasVisual = project.iconUrl != nil || !project.screenshotColors.isEmpty
            return hasVisual ? .tall : .small
        }
    }
}

enum MasonryTileSize: Sendable {
    case small
    case tall

    /// タイル全体 (visual + info) の target 高さ。実レンダリング高さではなく、
    /// 左右カラム振り分けアルゴリズムの累積高さ計算に使う目安値。
    var height: CGFloat {
        switch self {
        case .small: return 220
        case .tall: return 340
        }
    }
}
