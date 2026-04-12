import Foundation
import Network
import os

/// `NWPathMonitor` ラッパー。Sync 基盤の reachable 判定と UI オフラインバッジの情報源。
///
/// ## 同期方針
/// - `NWPathMonitor` は non-Sendable + callback が専用 queue で呼ばれる。
/// - State (isReachable + continuations) を `OSAllocatedUnfairLock<State>` で保護し、
///   `@unchecked Sendable` を安全に成立させる。
/// - NWPathMonitor の queue は `main` ではなく専用 `DispatchQueue(label: ..., qos: .utility)` を使う。
/// - 複数購読者のために `[UUID: AsyncStream<Bool>.Continuation]` で管理し、
///   `observe()` のたびに新 continuation を登録、`onTermination` で自動 cleanup。
final class NetworkMonitor: NetworkMonitorProtocol, @unchecked Sendable {
    private struct State {
        var isReachable: Bool = false
        var continuations: [UUID: AsyncStream<Bool>.Continuation] = [:]
        /// `start()` 冪等性フラグ。NWPathMonitor.start(queue:) は二重呼び出し時の挙動が
        /// Apple docs で未規定なので、View lifecycle の .task 再実行等による二重 start を
        /// 自前で防ぐ。
        var started: Bool = false
    }

    private let pathMonitor: NWPathMonitor
    private let queue: DispatchQueue
    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    var isReachable: Bool {
        get async { lock.withLock { $0.isReachable } }
    }

    init() {
        self.pathMonitor = NWPathMonitor()
        self.queue = DispatchQueue(label: "com.sanq3.createlog.networkmonitor", qos: .utility)
    }

    func start() async {
        // 冪等性 guard: 既に started なら no-op。
        // MainTabView の .task は View lifecycle で再実行される可能性があるため必須。
        let shouldStart = lock.withLock { state -> Bool in
            guard !state.started else { return false }
            state.started = true
            return true
        }
        guard shouldStart else { return }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let reachable = path.status == .satisfied
            // lock 内で state 更新 + continuations snapshot → lock 外で yield。
            // yield 中に consumer 側 onTermination が同期発火した場合、onTermination 内で
            // 再度 lock を取りに来るため nested lock deadlock の可能性がある
            // (OSAllocatedUnfairLock は非再帰)。snapshot pattern で回避する。
            let snapshot = self.lock.withLock { state -> [AsyncStream<Bool>.Continuation] in
                state.isReachable = reachable
                return Array(state.continuations.values)
            }
            for continuation in snapshot {
                continuation.yield(reachable)
            }
        }
        pathMonitor.start(queue: queue)
    }

    func stop() async {
        pathMonitor.cancel()
        // snapshot + removeAll を lock 内で実施 → lock 外で finish()。
        // finish() が同期で onTermination を発火しても、map は既に空なので removeValue は no-op。
        // lock 内で finish すると onTermination の再 lock と deadlock する。
        let snapshot = lock.withLock { state -> [AsyncStream<Bool>.Continuation] in
            state.started = false
            let all = Array(state.continuations.values)
            state.continuations.removeAll()
            return all
        }
        for continuation in snapshot {
            continuation.finish()
        }
    }

    func observe() -> AsyncStream<Bool> {
        AsyncStream { [weak self] continuation in
            let id = UUID()
            guard let self else {
                continuation.finish()
                return
            }
            // 登録 + initial value 取得を 1 回の lock で atomic に実施。
            // 2 段階 (currentValue 読み → 別 lock で登録) にすると、
            // その間に setReachable が走った時に stale な初期値を yield してしまう。
            let initialValue = self.lock.withLock { state -> Bool in
                state.continuations[id] = continuation
                return state.isReachable
            }
            // yield は lock 外で実施 (onTermination 同期発火との deadlock 回避)。
            continuation.yield(initialValue)
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { state in
                    state.continuations.removeValue(forKey: id)
                }
            }
        }
    }
}
