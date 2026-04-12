import Foundation

/// Offline-first 同期 service の public protocol。
///
/// ViewModels は直接 Supabase を呼ぶ代わりにこの protocol 経由で mutation を enqueue する。
/// 具象実装 (`OfflineSyncService`) は drain loop / retry / dead letter 管理を内部で行う。
///
/// ## 責務
/// - `start()` / `stop()`: drain loop lifecycle (idempotent)
/// - `enqueue(_:)`: ViewModels からの fire-and-forget 投入
/// - `flush()`: drain loop 1 iteration 分を手動 kick (テスト + 明示 flush 用)
/// - `observeState()`: UI 表示のための状態変化 AsyncStream
/// - `deadLetterCount`: dead letter バッジ表示用
///
/// ## 責務外
/// - conflict resolution (T7b)
/// - realtime subscription (T7c)
/// - 通知 telemetry (T7d, v1.1 後回し)
protocol SyncServiceProtocol: Sendable {
    /// 現在 dead letter になっている operation の件数。
    var deadLetterCount: Int { get async }

    /// drain loop を起動する (idempotent、2 回目以降は no-op)。
    /// `MainTabView.task` + `scenePhase .active` 遷移から呼ばれる。
    func start() async

    /// drain loop を停止し、保持している Task を cancel する。
    /// `scenePhase .background` 遷移時に呼ばれる。
    func stop() async

    /// 新規 mutation を queue に投入する (非 throwing、内部で log)。
    /// ViewModels は fire-and-forget で呼び出し、結果は observeState() で確認する。
    func enqueue(_ snapshot: QueuedOperationSnapshot) async

    /// drain loop 1 iteration 分を手動で実行する。
    /// テスト + Pull-to-refresh 等の明示 flush トリガー用。
    func flush() async

    /// 状態変化の AsyncStream。購読開始直後に現在値を 1 回 yield する。
    func observeState() -> AsyncStream<SyncState>
}
