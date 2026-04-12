import Foundation

/// ハッシュタグ Repository
///
/// T4 (2026-04-12): `trending_hashtags` view + post_hashtags + mentions 統合
/// v1 は read-only。attach/detach/mention は T7c SNS cache 経由で実装。
protocol HashtagRepositoryProtocol: Sendable {
    /// トレンドハッシュタグ取得 (`trending_hashtags` view、post_count 降順)
    func fetchTrending(limit: Int) async throws -> [HashtagDTO]
    /// 指定 post に紐づく hashtag 一覧
    func fetchByPost(postId: UUID) async throws -> [HashtagDTO]
}
