import Foundation

/// アプリ全体の設定値 (マジックナンバー集約)
enum AppConfig {
    // MARK: - Pagination

    /// フィード系ページサイズ (投稿/通知/検索結果)
    static let feedPageSize = 20
    /// プリフェッチ閾値: 残り何件で次ページ取得するか
    static let prefetchThreshold = 5

    // MARK: - Offline Queue

    /// オフライン操作キューの最大保持件数
    static let offlineQueueMaxSize = 100

    // MARK: - Cache

    /// Stale-While-Revalidate: キャッシュの有効期限 (秒)
    static let cacheStaleSeconds: TimeInterval = 300

    // MARK: - Network

    /// リクエストタイムアウト (秒)
    static let requestTimeoutSeconds: TimeInterval = 30
    /// リトライ最大回数
    static let maxRetries = 3
}
