import Foundation

/// 自動トラッキング Repository (heartbeats + api_keys)
///
/// T4 (2026-04-12): エディタ拡張・デスクトップアプリからの自動記録
/// - `heartbeats` は **read-only** (client は list のみ、書き込みは VS Code / Claude Code 拡張)
/// - `api_keys` は list / revoke のみ。**`createApiKey` は Edge Function 必須**
///   (client 平文生成は reverse engineering + SHA-256 hash 攻撃の risk、
///    `NetworkError.notAuthenticated` で stub、v1 では未実装)
protocol AutoTrackingRepositoryProtocol: Sendable {
    /// 自分の最近の heartbeats 取得 (timestamp 降順)
    func fetchRecentHeartbeats(limit: Int) async throws -> [HeartbeatDTO]
    /// 自分の API key 一覧
    func listMyApiKeys() async throws -> [ApiKeyDTO]
    /// API key 無効化 (is_active = false、hard delete せず履歴保持)
    func revokeApiKey(id: UUID) async throws
    /// API key 作成 — **v1 では未実装 stub、Edge Function 実装待ち**
    func createApiKey(name: String) async throws -> ApiKeyDTO
}
