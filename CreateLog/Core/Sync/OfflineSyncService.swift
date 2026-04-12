import Foundation
import os

/// Offline-first 同期の entry point。`OfflineQueueActor` の drain loop を管理する。
///
/// ## Lifecycle
/// - `start()`: drain loop Task を起動 (idempotent、2 回目以降は no-op)
/// - `stop()`: drain loop Task cancel + 内部 state reset
/// - `MainTabView` の `.task` + `@Environment(\.scenePhase)` で制御される想定
///
/// ## Drain loop (1 tick = 1 flush() 呼び出し + `DrainPriority.tickInterval` sleep)
/// `while !Task.isCancelled { await flush(); try? await Task.sleep(for: ...) }`
///
/// ## Flush (1 iteration の中身)
/// 1. `network.isReachable` check → false なら `.offline` state 遷移 + 早期 return
/// 2. `queue.dequeue(now:)` でループ、1 tick あたり最大
///    `DrainPriority.batchSize * SyncEntityType.allCases.count` operation
/// 3. `executors[entityType]` で dispatch、成功 → `markSuccess`、失敗 → `markFailure` (backoff)
/// 4. dead letter 件数を state に反映
///
/// ## Race defense (T7a-2 教訓)
/// `observeState()` / `updateState()` は `OSAllocatedUnfairLock<State>` で
/// state 更新 + continuations snapshot を lock 内で 1 回、yield は lock 外。
/// nested lock deadlock + onTermination 同期発火に対する構造的保護。
///
/// ## DI
/// - `queue`: `OfflineQueueActor` (in-memory test では separate ModelContainer で生成)
/// - `network`: `NetworkMonitorProtocol` (テストは `MockNetworkMonitor`)
/// - `executors`: entity type 別の `FlushExecuting` 配列 (dispatch table を内部構築)
final class OfflineSyncService: SyncServiceProtocol, @unchecked Sendable {
    // MARK: - State (lock-protected)

    private struct State {
        var started: Bool = false
        var currentSyncState: SyncState = .idle
        var continuations: [UUID: AsyncStream<SyncState>.Continuation] = [:]
        var drainTask: Task<Void, Never>?
    }

    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    // MARK: - Dependencies

    private let queue: OfflineQueueActor
    private let network: any NetworkMonitorProtocol
    /// entity type rawValue → executor dispatch table
    private let executors: [String: any FlushExecuting]

    // MARK: - Init

    init(
        queue: OfflineQueueActor,
        network: any NetworkMonitorProtocol,
        executors: [any FlushExecuting]
    ) {
        self.queue = queue
        self.network = network

        // Dispatch table: 1 executor が複数 entityType をサポートするケースも許容
        var dispatch: [String: any FlushExecuting] = [:]
        for executor in executors {
            for entityType in executor.supportedEntityTypes {
                dispatch[entityType] = executor
            }
        }
        self.executors = dispatch
    }

    // MARK: - SyncServiceProtocol

    var deadLetterCount: Int {
        get async {
            (try? await queue.deadLetterCount()) ?? 0
        }
    }

    func start() async {
        // Idempotency guard: started flag を lock 内で atomic に check + set
        let shouldStart = lock.withLock { state -> Bool in
            guard !state.started else { return false }
            state.started = true
            return true
        }
        guard shouldStart else { return }

        await network.start()

        // Drain loop: 1 tick ごとに flush() + sleep
        let task = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.flush()
                try? await Task.sleep(for: DrainPriority.tickInterval)
            }
        }
        lock.withLock { state in
            state.drainTask = task
        }
    }

    func stop() async {
        // started=false に戻しつつ drainTask を取り出して cancel
        let taskToCancel = lock.withLock { state -> Task<Void, Never>? in
            guard state.started else { return nil }
            state.started = false
            let t = state.drainTask
            state.drainTask = nil
            return t
        }
        taskToCancel?.cancel()
        await network.stop()
    }

    func enqueue(_ snapshot: QueuedOperationSnapshot) async {
        do {
            try await queue.enqueue(snapshot)
        } catch {
            // Local save 失敗は極めて稀 (SwiftData disk full 等)。log のみで swallow。
            // ViewModels は fire-and-forget で呼び出す前提。
            return
        }
        // flush() を待たず immediate に .draining 状態を yield (UI feedback 優先)
        updateState(.draining(remaining: 1))
    }

    func flush() async {
        // Reachability check: false なら .offline 遷移して早期 return
        let reachable = await network.isReachable
        guard reachable else {
            updateState(.offline)
            return
        }

        // 1 flush あたりの hard cap (無限 drain による main thread starve 回避)
        let maxPerFlush = DrainPriority.batchSize * DrainPriority.orderedEntityTypes.count
        var drainedCount = 0

        while drainedCount < maxPerFlush {
            guard !Task.isCancelled else { break }

            // 次 operation を priority ASC + createdAt ASC で 1 件取得
            let snapshot: QueuedOperationSnapshot?
            do {
                snapshot = try await queue.dequeue(now: Date())
            } catch {
                // Fetch 失敗は queue 側の問題。次 tick で再試行。
                break
            }
            guard let snapshot else { break }  // queue empty

            // Dispatch: entity type に対応する executor を検索
            guard let executor = executors[snapshot.entityType] else {
                // 未対応 entity type → failure mark で backoff、maxAttempts 到達で dead letter
                try? await queue.markFailure(
                    id: snapshot.id,
                    error: "no executor for \(snapshot.entityType)",
                    now: Date()
                )
                continue
            }

            // Execute + mark result
            do {
                try await executor.execute(snapshot)
                try await queue.markSuccess(id: snapshot.id)
                drainedCount += 1
            } catch {
                try? await queue.markFailure(
                    id: snapshot.id,
                    error: String(describing: error),
                    now: Date()
                )
            }
        }

        // Final state update: dead letter > draining > idle の優先度
        let deadCount = (try? await queue.deadLetterCount()) ?? 0
        if deadCount > 0 {
            updateState(.deadLettered(count: deadCount))
        } else if drainedCount > 0 {
            updateState(.draining(remaining: drainedCount))
        } else {
            updateState(.idle)
        }
    }

    func observeState() -> AsyncStream<SyncState> {
        AsyncStream { [weak self] continuation in
            let id = UUID()
            guard let self else {
                continuation.finish()
                return
            }
            // T7a-2 pattern: 登録 + initial value 取得を 1 lock scope で atomic に
            let initial = self.lock.withLock { state -> SyncState in
                state.continuations[id] = continuation
                return state.currentSyncState
            }
            // yield は lock 外で実施 (onTermination 同期発火との deadlock 回避)
            continuation.yield(initial)
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                _ = self.lock.withLock { state in
                    state.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    // MARK: - Private

    /// state を更新して全 subscriber に snapshot yield する。
    /// T7a-2 の nested lock 回避 pattern: lock 内で state 更新 + continuations eager copy、
    /// yield は lock 外。
    private func updateState(_ newState: SyncState) {
        let snapshot = lock.withLock { state -> [AsyncStream<SyncState>.Continuation] in
            state.currentSyncState = newState
            return Array(state.continuations.values)
        }
        for continuation in snapshot {
            continuation.yield(newState)
        }
    }
}
