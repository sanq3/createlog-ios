import Foundation

/// `SDOfflineOperation` の actor 境界越え用 Sendable スナップショット。
///
/// SwiftData の `@Model` クラスは Sendable 準拠していないため、
/// `OfflineQueueActor` の外に渡す値は必ずこの struct にコピーして渡す。
struct QueuedOperationSnapshot: Sendable {
    let id: UUID
    let idempotencyKey: UUID
    let entityType: String
    let operationType: String
    let payload: Data
    let priority: Int
    let attemptCount: Int
    let lastError: String?

    init(from model: SDOfflineOperation) {
        self.id = model.id
        self.idempotencyKey = model.idempotencyKey
        self.entityType = model.entityType
        self.operationType = model.operationType
        self.payload = model.payload
        self.priority = model.priority
        self.attemptCount = model.attemptCount
        self.lastError = model.lastError
    }

    /// Test / enqueue 経路で手動構築するための designated init。
    init(
        id: UUID = UUID(),
        idempotencyKey: UUID = UUID(),
        entityType: String,
        operationType: String,
        payload: Data,
        priority: Int,
        attemptCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.entityType = entityType
        self.operationType = operationType
        self.payload = payload
        self.priority = priority
        self.attemptCount = attemptCount
        self.lastError = lastError
    }
}
