import Foundation

/// Sync 基盤で発生する既知のエラー種別。
///
/// `FlushExecuting.execute()` / `OfflineSyncService.flush()` / `LogFlushExecutor` 等が throw する。
/// `RetryPolicy` はこれらのケースを見て「即時 retry」「backoff 後 retry」「dead letter 行き」を判断する。
///
/// T7a-3 scope では最小セット (decodingFailed / networkUnavailable / serverError)。
/// T7b で conflict resolution を追加する際に `idempotencyConflict` / `staleWrite` 等を拡張予定。
enum SyncError: Error, Sendable {
    /// payload JSON decode 失敗 / `SyncEntityType` / `SyncOperationType` rawValue 不一致。
    /// 基本的に dead letter 直行 (retry しても decode は成功しない)。
    case decodingFailed

    /// `NWPathMonitor` で reachable=false 中に execute を呼ばれた場合。
    /// retry 時にネットワーク復帰を待つ。
    case networkUnavailable

    /// 5xx / timeout / その他 server 起因の一時障害。backoff 後 retry。
    case serverError(String)

    /// 対応する `FlushExecuting` が見つからなかった場合。
    /// dispatch table の設定ミス。基本的に dead letter 直行。
    case noExecutor(entityType: String)
}
