import Foundation
@testable import CreateLog

/// テスト用の `NetworkMonitorProtocol` スタブ。
///
/// `NWPathMonitor` を使わず、`setReachable(_:)` で任意に疎通状態を操作できる。
/// T7a-3 の `OfflineSyncService` テストで「オフライン → オンライン復帰で flush 発火」
/// 等のシナリオを再現する想定。
///
/// - 複数購読者を `[UUID: AsyncStream<Bool>.Continuation]` で管理
/// - `NSLock` でシンプルに値を保護 (テスト用なので OSAllocatedUnfairLock の性能は不要)
/// - 本番 `NetworkMonitor` と同じ **lock 内 snapshot → lock 外 yield** pattern で統一
///   (nested lock deadlock 回避 + atomic initial value retrieval)
final class MockNetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _isReachable: Bool
    private var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]

    init(initial: Bool = true) {
        self._isReachable = initial
    }

    var isReachable: Bool {
        get async {
            lock.lock()
            defer { lock.unlock() }
            return _isReachable
        }
    }

    /// テストから疎通状態を変更する。全購読者に変化を通知する。
    /// lock 内で state 更新 + snapshot 取得 → lock 外で yield (NetworkMonitor と同 pattern)。
    func setReachable(_ value: Bool) {
        lock.lock()
        _isReachable = value
        // Array(...) で eager copy を明示 (COW 依存を避けて collection type 変更耐性を上げる)
        let snapshot = Array(continuations.values)
        lock.unlock()
        for continuation in snapshot {
            continuation.yield(value)
        }
    }

    func observe() -> AsyncStream<Bool> {
        AsyncStream { [weak self] continuation in
            let id = UUID()
            guard let self else {
                continuation.finish()
                return
            }
            // HIGH #3 fix: 登録 + initial value 取得を 1 lock scope で atomic に実施。
            // 2 段 lock (currentValue 読み → 別 lock で登録) にすると、その間に
            // setReachable が走った時に stale な初期値を yield してしまう race が発生する。
            self.lock.lock()
            self.continuations[id] = continuation
            let initialValue = self._isReachable
            self.lock.unlock()
            // yield は lock 外で実施 (onTermination 同期発火との deadlock 回避)。
            continuation.yield(initialValue)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                self.lock.lock()
                self.continuations.removeValue(forKey: id)
                self.lock.unlock()
            }
        }
    }

    func start() async {}
    func stop() async {}
}
