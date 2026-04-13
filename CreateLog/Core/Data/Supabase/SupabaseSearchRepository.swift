import Foundation
import Supabase

/// SearchRepositoryProtocol の Supabase実装
final class SupabaseSearchRepository: SearchRepositoryProtocol, Sendable {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func search(query: String, limit: Int) async throws -> SearchResults {
        // PostgREST メタ文字・ワイルドカード・制御文字を除去 (インジェクション対策)
        let sanitized = Self.sanitizeQuery(query)
        guard !sanitized.isEmpty else {
            return SearchResults(users: [], posts: [], apps: [])
        }

        async let users: [ProfileDTO] = client
            .from("profiles")
            .select()
            .or("display_name.ilike.%\(sanitized)%,handle.ilike.%\(sanitized)%")
            .limit(limit)
            .execute()
            .value

        async let posts: [PostDTO] = client
            .from("posts")
            .select()
            .ilike("content", pattern: "%\(sanitized)%")
            .eq("visibility", value: "public")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        async let apps: [AppDTO] = client
            .from("apps")
            .select()
            .or("name.ilike.%\(sanitized)%,description.ilike.%\(sanitized)%")
            .eq("status", value: "published")
            .limit(limit)
            .execute()
            .value

        return try await SearchResults(users: users, posts: posts, apps: apps)
    }

    /// PostgRESTフィルタ用のクエリサニタイズ
    /// 英数字・日本語・スペースのみ許可。ワイルドカード(%, _)、カンマ、ドット等の制御文字を除去
    static func sanitizeQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // 許可: 英数字、日本語 (ひらがな・カタカナ・漢字)、スペース
        let allowedChars = trimmed.unicodeScalars.filter { scalar in
            CharacterSet.alphanumerics.contains(scalar) ||
            (0x3040...0x309F).contains(scalar.value) || // ひらがな
            (0x30A0...0x30FF).contains(scalar.value) || // カタカナ
            (0x4E00...0x9FFF).contains(scalar.value) || // CJK統合漢字
            scalar == " "
        }
        return String(String.UnicodeScalarView(allowedChars))
    }

    func fetchTrendingTags() async throws -> [String] {
        // `trending_hashtags` view を参照 (T4 で導入済み)。
        // HashtagRepository と重複するが、Discover 画面は文字列配列のみ欲しいので直接 view を叩く。
        struct TagRow: Decodable {
            let tag: String
        }
        let rows: [TagRow] = try await client
            .from("trending_hashtags")
            .select("tag")
            .limit(20)
            .execute()
            .value
        return rows.map(\.tag)
    }

    func fetchSuggestedUsers(limit: Int) async throws -> [ProfileDTO] {
        let result: [ProfileDTO] = try await client
            .from("profiles")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        return result
    }
}
