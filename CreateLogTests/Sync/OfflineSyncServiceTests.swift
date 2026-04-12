import Testing
import SwiftData
import Foundation
@testable import CreateLog

/// T7a-3: `OfflineSyncService` の drain loop + state management を in-memory で検証する。
///
/// 実 drain loop (tick interval 1s) は start/stop idempotency のみ実機テストし、
/// dispatch / failure / offline / observeState は `flush()` 直接呼び出しで
/// deterministic に検証する (tick を跨がず fast fail)。
@Suite("Offline Sync Service")
struct OfflineSyncServiceTests {

    // MARK: - Helpers

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            SDCategory.self,
            SDProject.self,
            SDTimeEntry.self,
            SDOfflineOperation.self,
            SDLogCache.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func logSnapshot(_ text: String) -> QueuedOperationSnapshot {
        QueuedOperationSnapshot(
            entityType: SyncEntityType.log.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: Data(text.utf8),
            priority: SyncEntityType.log.drainPriority
        )
    }

    // MARK: - Lifecycle

    @Test("start() は 2 回呼んでも drain loop は 1 本しか動かず、executor は 1 op あたり 1 回だけ呼ばれる")
    func testStartIsIdempotent() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)
        let executor = MockFlushExecutor()
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        // start を 2 回。内部 started flag で 2 回目は no-op になる前提。
        // loop が 2 本起動していた場合、actor 越しの dequeue 間の race で
        // 同じ op が 2 回 dispatch されうる (executor.count == 2 で検出可能)。
        await service.start()
        await service.start()

        try await queue.enqueue(logSnapshot("idempotent"))
        // tick 1s + 初回 flush + margin
        try await Task.sleep(for: .milliseconds(1500))
        await service.stop()

        #expect(executor.executedSnapshots.count == 1)
    }

    @Test("stop() で drain loop が停止し、以降 enqueue しても executor は呼ばれない")
    func testStopCancelsDrainLoop() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)
        let executor = MockFlushExecutor()
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        await service.start()
        // 初回 flush (empty queue) が走るだけの短い wait
        try await Task.sleep(for: .milliseconds(30))
        await service.stop()

        // stop 後に enqueue → tick interval を跨いでも executor は呼ばれない
        try await queue.enqueue(logSnapshot("after-stop"))
        try await Task.sleep(for: .milliseconds(1500))

        #expect(executor.executedSnapshots.isEmpty)
    }

    // MARK: - Flush dispatch

    @Test("flush() で queue の operation が executor に dispatch され markSuccess で queue から消える")
    func testFlushDispatchesToExecutor() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)
        let executor = MockFlushExecutor()
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        let snapshot = logSnapshot("dispatch")
        try await queue.enqueue(snapshot)
        await service.flush()

        #expect(executor.executedSnapshots.count == 1)
        #expect(executor.executedSnapshots.first?.id == snapshot.id)

        // markSuccess 経路で queue から消えている
        let next = try await queue.dequeue()
        #expect(next == nil)
    }

    @Test("executor が throw したら markFailure 経路で attemptCount が進み lastError が記録される")
    func testFlushRetriesOnError() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)
        let executor = MockFlushExecutor()
        executor.setError(SyncError.serverError("boom"))
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        let snapshot = logSnapshot("retry")
        try await queue.enqueue(snapshot)
        await service.flush()

        // execute 自体は 1 回呼ばれている
        #expect(executor.executedSnapshots.count == 1)

        // backoff 時刻を十分飛ばして dequeue し、attemptCount が増えていることを確認
        let future = Date().addingTimeInterval(ExponentialBackoff.capSeconds + 10)
        let retried = try await queue.dequeue(now: future)
        #expect(retried?.id == snapshot.id)
        #expect(retried?.attemptCount == 1)
        #expect(retried?.lastError?.contains("boom") == true)
    }

    @Test("未対応 entityType は executor にたどり着かず markFailure 経路 (dispatch fall-through) で処理される")
    func testFlushFallsThroughForUnknownEntity() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)
        let executor = MockFlushExecutor(supportedEntityTypes: [SyncEntityType.log.rawValue])
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        // log 以外の entity type (executor dispatch table 未登録)
        let unknown = QueuedOperationSnapshot(
            entityType: SyncEntityType.comment.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: Data("??".utf8),
            priority: SyncEntityType.comment.drainPriority
        )
        try await queue.enqueue(unknown)
        await service.flush()

        // executor は呼ばれていない (dispatch nil で fall-through)
        #expect(executor.executedSnapshots.isEmpty)

        // markFailure 経路で attemptCount が進んでいる
        let future = Date().addingTimeInterval(ExponentialBackoff.capSeconds + 10)
        let retried = try await queue.dequeue(now: future)
        #expect(retried?.attemptCount == 1)
        #expect(retried?.lastError?.contains("no executor") == true)
    }

    // MARK: - State

    @Test("isReachable == false の間は flush() が .offline state を立てて早期 return する")
    func testOfflineStateWhenNetworkDown() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: false)  // 初期オフライン
        let executor = MockFlushExecutor()
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        try await queue.enqueue(logSnapshot("offline-op"))
        await service.flush()

        // network=false → executor 呼ばれず、queue にも残っている
        #expect(executor.executedSnapshots.isEmpty)
        let stillQueued = try await queue.dequeue()
        #expect(stillQueued != nil)

        // observeState() の初期 yield は .offline (flush で state が既に更新されている)
        let stream = service.observeState()
        var iter = stream.makeAsyncIterator()
        let state = await iter.next()
        #expect(state == .offline)
    }

    @Test("observeState() は現在 state を初期値で yield し、以降の state 変化も受け取れる")
    func testStateStreamYieldsOnUpdate() async throws {
        let container = try makeContainer()
        let queue = OfflineQueueActor(modelContainer: container)
        let network = MockNetworkMonitor(initial: true)  // 初期オンライン
        let executor = MockFlushExecutor()
        let service = OfflineSyncService(
            queue: queue,
            network: network,
            executors: [executor]
        )

        // AsyncStream は default unbounded buffer なので、yield は全て buffer に蓄積される。
        // subscribe → 初期 yield(.idle)、network を落として flush → yield(.offline) の順で iter.next() が読める。
        let stream = service.observeState()
        var iter = stream.makeAsyncIterator()

        let initial = await iter.next()
        #expect(initial == .idle)

        network.setReachable(false)
        await service.flush()

        let next = await iter.next()
        #expect(next == .offline)
    }
}
