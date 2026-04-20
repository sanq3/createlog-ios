import Foundation

/// 同期系で使う Date 比較用の丸め namespace。
///
/// ## 背景 (T7b)
/// LWW (Last Write Wins) conflict resolution で `local.updatedAtRemote` と `remote.updatedAt` を
/// 直接 == 比較すると、JSON ↔ Date ↔ TimeInterval 変換による sub-millisecond 揺らぎで
/// 「同じ瞬間に書いたはずなのに不一致」が頻発する。
///
/// ## 解決策
/// 1ms 単位に丸めた `Date` 同士で比較する。これは PostgREST の `timestamptz` 解像度
/// (microsecond) と Swift `Date` (Double seconds) の相互変換で発生する誤差を吸収する。
///
/// ## 由来
/// T7b planner patch v1.1 (2026-04-12) で T7c の SDPostCache.syncedAt 比較と統一するため
/// 独立 namespace 化。`LogCacheWriter.round1ms` のような instance method 化はせず、
/// 全 sync エンティティから static 参照できるようにする。
enum SyncDateRounding {
    /// `Date` を 1 ミリ秒単位に丸める。
    /// timeIntervalSince1970 を 1000 倍 → round → 1000 で割って Date 化。
    /// `nonisolated`: 純粋関数 (Date Sendable) のため、`@ModelActor` 等の
    /// カスタム actor 文脈から同期呼び出し可能にする。`SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor`
    /// 下でも cross-actor error にならない。
    nonisolated static func round1ms(_ date: Date) -> Date {
        let ms = (date.timeIntervalSince1970 * 1000.0).rounded()
        return Date(timeIntervalSince1970: ms / 1000.0)
    }

    /// 2 つの `Date` を 1ms 解像度で等価判定する。
    nonisolated static func equal1ms(_ lhs: Date, _ rhs: Date) -> Bool {
        round1ms(lhs) == round1ms(rhs)
    }

    /// `lhs` の方が `rhs` より厳密に新しい (1ms 解像度)。
    /// LWW 判定で「remote が local より新しい場合のみ cache を上書きする」に使う。
    nonisolated static func isNewer(_ lhs: Date, than rhs: Date) -> Bool {
        round1ms(lhs) > round1ms(rhs)
    }
}
