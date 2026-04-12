import Testing
import SwiftData
import Foundation
@testable import CreateLog

/// T7a-1 / T7a-2: `SDOfflineOperation` の schema 共存確認、および
/// `OfflineQueueActor` / `ExponentialBackoff` の動作を in-memory ModelContainer で検証する。
///
/// - schema: V2 schema で SDOfflineOperation と既存 4 entity (SDCategory/SDProject/SDTimeEntry) の共存
/// - queue: enqueue / dequeue (priority + createdAt 優先度) / markSuccess / markFailure / deadLetter 遷移
/// - backoff: ExponentialBackoff の cap / delay 数値
@Suite("Offline Queue")
struct OfflineQueueTests {

    // MARK: - Helpers

    private func makeV2Container() throws -> ModelContainer {
        let schema = Schema([
            SDCategory.self,
            SDProject.self,
            SDTimeEntry.self,
            SDOfflineOperation.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    private func samplePayload(_ text: String) -> Data {
        Data(text.utf8)
    }

    // MARK: - Schema migration

    @Test("V2 schema で SDOfflineOperation と既存 4 entity (SDCategory/SDProject/SDTimeEntry) が共存できる")
    func testSchemaAdditionDoesNotBreakExistingEntities() async throws {
        // 注: in-memory ModelContainer は永続ストレージを共有しないため、
        // V1→V2 の lightweight migration を in-memory テストでは再現できない。
        // ここでは V2 schema 下で全 4 entity type が正常に insert/fetch できることを確認し、
        // 「SDOfflineOperation の追加で既存 @Model の読み書きが壊れていない」ことを保証する。
        let container = try makeV2Container()
        let context = ModelContext(container)

        // 既存 entity
        // colorIndex: 1 = clCat01 (SDCategory default 値 sentinel、Assets 最小有効値)
        let category = SDCategory(name: "test-seed", colorIndex: 1, isStandard: true, sortOrder: 0)
        context.insert(category)
        let project = SDProject(
            name: "proj", platforms: ["iOS"], techStack: ["Swift"], category: category
        )
        context.insert(project)
        let entry = SDTimeEntry(
            startDate: Date(),
            durationMinutes: 25,
            projectName: "proj",
            categoryName: "test-seed"
        )
        context.insert(entry)

        // 新規 entity
        let op = SDOfflineOperation(
            entityType: "log",
            operationType: "insert",
            payload: Data("{}".utf8),
            priority: 3
        )
        context.insert(op)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SDCategory>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SDProject>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SDTimeEntry>()) == 1)

        let ops = try context.fetch(FetchDescriptor<SDOfflineOperation>())
        #expect(ops.count == 1)
        #expect(ops.first?.entityType == "log")
        #expect(ops.first?.priority == 3)
        #expect(ops.first?.attemptCount == 0)
        #expect(ops.first?.isDeadLetter == false)
        #expect(ops.first?.nextRetryAt == .distantPast)
    }

    // MARK: - OfflineQueueActor

    @Test("enqueue → dequeue で同じ operation が snapshot として取り出せる")
    func testEnqueueThenDequeue() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        let snapshot = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("payload-a"),
            priority: 3
        )
        try await actor.enqueue(snapshot)

        let popped = try await actor.dequeue()
        #expect(popped?.id == snapshot.id)
        #expect(popped?.entityType == "log")
        #expect(popped?.payload == samplePayload("payload-a"))
    }

    @Test("dequeue は priority ASC の順で取り出す (低い priority 値が優先)")
    func testDequeueRespectsPriorityOrder() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        // 先に priority=5 を enqueue、後から priority=1 を enqueue
        let low = QueuedOperationSnapshot(
            entityType: "comment",
            operationType: "insert",
            payload: samplePayload("low"),
            priority: 5
        )
        try await actor.enqueue(low)

        let high = QueuedOperationSnapshot(
            entityType: "project",
            operationType: "insert",
            payload: samplePayload("high"),
            priority: 1
        )
        try await actor.enqueue(high)

        // priority が低い (= 優先度高い) 方が先に取り出される
        let first = try await actor.dequeue()
        #expect(first?.id == high.id)
    }

    @Test("同一 priority の operation は createdAt ASC で取り出される (FIFO tie-break)")
    func testDequeueRespectsCreatedAtWithinSamePriority() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        // 同じ priority=3 で 2 回 enqueue、間に sleep を入れて createdAt に差をつける
        let first = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("first"),
            priority: 3
        )
        try await actor.enqueue(first)
        try await Task.sleep(for: .milliseconds(10))

        let second = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("second"),
            priority: 3
        )
        try await actor.enqueue(second)

        // 先に enqueue した方 (古い createdAt) が優先
        let popped = try await actor.dequeue()
        #expect(popped?.id == first.id)
    }

    @Test("markSuccess で queue から削除される")
    func testMarkSuccessRemovesOperation() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        let snapshot = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("done"),
            priority: 3
        )
        try await actor.enqueue(snapshot)
        try await actor.markSuccess(id: snapshot.id)

        let next = try await actor.dequeue()
        #expect(next == nil)
    }

    @Test("markFailure は attemptCount を増やし nextRetryAt を設定する")
    func testMarkFailureIncrementsAttempt() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        let snapshot = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("fail-me"),
            priority: 3
        )
        try await actor.enqueue(snapshot)

        let now = Date()
        try await actor.markFailure(id: snapshot.id, error: "network", now: now)

        // nextRetryAt が未来に設定されている間は dequeue で弾かれる
        let tooEarly = try await actor.dequeue(now: now)
        #expect(tooEarly == nil)

        // 十分先の now を渡せば再び取り出せる
        let future = now.addingTimeInterval(ExponentialBackoff.capSeconds + 10)
        let retryable = try await actor.dequeue(now: future)
        #expect(retryable?.id == snapshot.id)
        #expect(retryable?.attemptCount == 1)
        #expect(retryable?.lastError == "network")
    }

    @Test("maxAttempts 到達で isDeadLetter=true になり dequeue から除外される")
    func testDeadLetterAfterMaxAttempts() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        let snapshot = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("doomed"),
            priority: 3
        )
        try await actor.enqueue(snapshot)

        let now = Date()
        for _ in 0..<ExponentialBackoff.maxAttempts {
            try await actor.markFailure(id: snapshot.id, error: "fatal", now: now)
        }

        let deadCount = try await actor.deadLetterCount()
        #expect(deadCount == 1)

        // 十分未来時刻でも dead letter は dequeue から弾かれる
        let far = now.addingTimeInterval(3600)
        let popped = try await actor.dequeue(now: far)
        #expect(popped == nil)
    }

    @Test("attemptCount = maxAttempts - 1 の次 markFailure で deadLetter 境界遷移")
    func testDeadLetterBoundaryTransition() async throws {
        let container = try makeV2Container()
        let actor = OfflineQueueActor(modelContainer: container)

        let snapshot = QueuedOperationSnapshot(
            entityType: "log",
            operationType: "insert",
            payload: samplePayload("boundary"),
            priority: 3
        )
        try await actor.enqueue(snapshot)

        // maxAttempts - 1 回失敗させる (まだ dead letter にならない)
        let base = Date()
        for _ in 0..<(ExponentialBackoff.maxAttempts - 1) {
            try await actor.markFailure(id: snapshot.id, error: "retry", now: base)
        }

        // この時点では dead letter は 0 件、時刻を十分先に飛ばせば取り出せる
        let preCount = try await actor.deadLetterCount()
        #expect(preCount == 0)
        let future = base.addingTimeInterval(ExponentialBackoff.capSeconds + 10)
        let stillAlive = try await actor.dequeue(now: future)
        #expect(stillAlive?.id == snapshot.id)
        #expect(stillAlive?.attemptCount == ExponentialBackoff.maxAttempts - 1)

        // maxAttempts 回目の失敗で dead letter に遷移
        try await actor.markFailure(id: snapshot.id, error: "final", now: future)

        let postCount = try await actor.deadLetterCount()
        #expect(postCount == 1)
        let nextPop = try await actor.dequeue(now: future.addingTimeInterval(3600))
        #expect(nextPop == nil)
    }

    // MARK: - ExponentialBackoff

    @Test("ExponentialBackoff は 60s で cap される")
    func testBackoffCapsAt60Seconds() {
        #expect(ExponentialBackoff.delay(for: 0) == 1)
        #expect(ExponentialBackoff.delay(for: 1) == 2)
        #expect(ExponentialBackoff.delay(for: 5) == 32)
        #expect(ExponentialBackoff.delay(for: 6) == 60)  // 64 → cap
        #expect(ExponentialBackoff.delay(for: 10) == 60)
        #expect(ExponentialBackoff.delay(for: 19) == 60)
    }
}
