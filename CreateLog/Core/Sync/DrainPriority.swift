import Foundation

/// `OfflineSyncService` の drain loop パラメタを集約する namespace。
///
/// `SyncEntityType.drainPriority` (1-indexed、FK 依存順) と、drain loop の
/// batch size / tick interval / priority-sorted 配列を 1 箇所に codify する。
///
/// ## 設計判断
/// - enum にしてインスタンス化を禁止 (定数 namespace)
/// - batch size / tick interval を `SyncEntityType` に持たせず、ここで分離
///   (drain loop の挙動パラメタと entity type の定義を混ぜない)
/// - `orderedEntityTypes` は allCases + drainPriority ソートで毎回計算せず 1 回だけ評価される
///   (`static let` のため遅延評価)
enum DrainPriority {
    /// 1 drain tick で 1 entity type あたり処理する最大 operation 数。
    /// T7a-1 再評価予約 #2: Supabase batch upsert 対応時に 10 → 25 に引き上げ検討。
    static let batchSize: Int = 10

    /// 1 drain loop iteration 後の sleep 間隔。
    /// reachable=false の場合は drain をスキップしてこの間隔で再 check する。
    static let tickInterval: Duration = .seconds(1)

    /// drain 優先度順にソート済の `SyncEntityType` 配列 (static let で 1 回だけ計算)。
    /// FK 依存順: profile → project → category → log → post → comment → like → follow → notification
    static let orderedEntityTypes: [SyncEntityType] = SyncEntityType.allCases
        .sorted { $0.drainPriority < $1.drainPriority }
}
