import Foundation

/// `QueuedOperationSnapshot` 1 件を remote に送信する責務を抽象化する。
///
/// entity type 別に具象実装を持ち、`OfflineSyncService` が drain 時に
/// `supportedEntityTypes` を dispatch key として呼び分ける。
///
/// ## 戻り値の規約
/// - 成功: void return (呼び出し元で `OfflineQueueActor.markSuccess(id:)` を呼ぶ)
/// - 失敗: `SyncError` を throw (呼び出し元で `RetryPolicy` が次 retry 時刻を決める)
///
/// ## 冪等性
/// `snapshot.idempotencyKey` を remote に渡し、server-side dedup に委譲する。
/// local 側は「同一 idempotencyKey で 2 回 execute されても 1 回分の効果」を保証しなくてよい。
///
/// ## T7a-3 scope
/// - `LogFlushExecutor` (具象 1 本) のみ提供
/// - body は `// TODO: T7b` コメント付きの empty success
/// - DI 配線と protocol 経路の検証が目的 (実 Supabase 呼び出しは T7b で RecordingViewModel 置換と同時実装)
protocol FlushExecuting: Sendable {
    /// 対応する entity type の rawValue 配列 (dispatch key)。
    /// 通常 1 executor = 1 entity type だが、複数をサポートする executor も許容する。
    var supportedEntityTypes: [String] { get }

    /// snapshot を remote に送信する。
    /// - Parameter snapshot: queue から dequeue された operation
    /// - Throws: `SyncError` のいずれか (decodingFailed / networkUnavailable / serverError)
    func execute(_ snapshot: QueuedOperationSnapshot) async throws
}
