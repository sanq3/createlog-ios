import Foundation

/// 検索結果
struct SearchResults: Sendable {
    let users: [ProfileDTO]
    let posts: [PostDTO]
    let apps: [AppDTO]
}

/// 検索・発見のデータアクセス
protocol SearchRepositoryProtocol: Sendable {
    /// 横断検索
    func search(query: String, limit: Int) async throws -> SearchResults
    /// トレンドタグ取得
    func fetchTrendingTags() async throws -> [String]
    /// おすすめユーザー取得
    func fetchSuggestedUsers(limit: Int) async throws -> [ProfileDTO]
}
