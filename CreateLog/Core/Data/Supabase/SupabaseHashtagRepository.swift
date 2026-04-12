import Foundation
import Supabase

/// HashtagRepositoryProtocol の Supabase 実装
///
/// T4 (2026-04-12): trending_hashtags view + post_hashtags 経由の join
final class SupabaseHashtagRepository: HashtagRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchTrending(limit: Int) async throws -> [HashtagDTO] {
        let result: [HashtagDTO] = try await client
            .from("trending_hashtags")
            .select()
            .limit(limit)
            .execute()
            .value
        return result
    }

    func fetchByPost(postId: UUID) async throws -> [HashtagDTO] {
        // post_hashtags を経由して hashtags を join
        // select("hashtag:hashtags(*)") で embed
        struct JoinRow: Decodable {
            let hashtag: HashtagDTO
        }
        let rows: [JoinRow] = try await client
            .from("post_hashtags")
            .select("hashtag:hashtags(*)")
            .eq("post_id", value: postId.uuidString)
            .execute()
            .value
        return rows.map(\.hashtag)
    }
}
