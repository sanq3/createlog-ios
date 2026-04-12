import Foundation

/// オフライン queue のリトライ間隔を決める指数バックオフ。
///
/// 1s, 2s, 4s, 8s, 16s, 32s, 60s (cap) のシーケンス。
/// 20 回 attempt で合計およそ 20 分の自動リトライを行い、以降は dead letter とする。
enum ExponentialBackoff {
    /// リトライ上限。この回数に達した operation は dead letter 扱い。
    static let maxAttempts = 20

    /// バックオフの上限秒数。これ以上は待たない。
    static let capSeconds: TimeInterval = 60.0

    /// `attempt` 回目の失敗直後に次リトライまで待つべき秒数を返す。
    /// 例: attempt=0 → 1s, attempt=1 → 2s, attempt=5 → 32s, attempt=6+ → 60s
    static func delay(for attempt: Int) -> TimeInterval {
        min(pow(2.0, Double(attempt)), capSeconds)
    }

    /// 次リトライの絶対時刻を算出する。
    static func nextRetryAt(from now: Date, attempt: Int) -> Date {
        now.addingTimeInterval(delay(for: attempt))
    }
}
