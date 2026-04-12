import Foundation

/// `OfflineSyncService` の現在状態。UI が `observeState()` で購読し、
/// オフラインバッジ / 同期中インジケータ / dead letter 警告等の表示を切り替える。
///
/// ## 状態遷移
/// - `.idle`: drain 対象がなく、reachable。静止状態
/// - `.draining(remaining:)`: flush 中 (remaining は approximate、正確な残数ではない)
/// - `.offline`: `NetworkMonitor.isReachable == false` で flush 不能。バッジ表示
/// - `.deadLettered(count:)`: 1 件以上 dead letter になった。ユーザー通知 + dismiss 動線必要
///
/// ## Equatable 理由
/// テストで `#expect(state == .offline)` のように比較するため。
/// `.draining(remaining: Int)` / `.deadLettered(count: Int)` の associated value も比較対象。
enum SyncState: Sendable, Equatable {
    case idle
    case draining(remaining: Int)
    case offline
    case deadLettered(count: Int)
}
