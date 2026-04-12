import Foundation

/// ネットワーク疎通監視 protocol。Sync 基盤の reachable 判定と UI オフラインバッジ表示に使う。
///
/// 実装 (`NetworkMonitor`) は `NWPathMonitor` をラップし、DispatchQueue 経由で状態変化を
/// AsyncStream に流す。呼び出し側は `observe()` の for-await で変化を受け取る。
protocol NetworkMonitorProtocol: Sendable {
    /// 現在疎通可能か (呼び出し時点のスナップショット)。
    var isReachable: Bool { get async }

    /// 疎通状態の変化を監視する AsyncStream。
    /// 購読開始直後に現在値を一度 yield してから、以降は変化のたびに yield する。
    func observe() -> AsyncStream<Bool>

    /// 監視開始 (`NWPathMonitor.start` ラップ)。アプリ起動時 1 回呼ぶ想定。
    func start() async

    /// 監視停止 + 全 continuation 終了。アプリ終了時 or テストクリーンアップ用。
    func stop() async
}
