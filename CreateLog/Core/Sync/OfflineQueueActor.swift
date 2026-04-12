import Foundation
import SwiftData

/// オフライン queue の排他アクセスを保証する `@ModelActor`。
///
/// SwiftData の `ModelContext` は thread-safe ではないため、
/// queue 操作 (enqueue/dequeue/mark*) は必ずこの actor を経由する。
///
/// ## 責務
/// - enqueue: 新規 operation を永続化
/// - dequeue: drain 対象 1 件を snapshot として取り出す (priority ASC, createdAt ASC)
/// - markSuccess: 成功した operation を削除
/// - markFailure: 失敗カウントを増やし、next retry 時刻を更新、上限到達で dead letter に遷移
///
/// ## 責務外 (T7a-1 範囲外)
/// - 実際のネットワーク呼び出し (drain loop は後続 segment で実装)
/// - conflict 解決 (T7b)
/// - realtime / polling (T7c)
@ModelActor
actor OfflineQueueActor {

    // MARK: - Enqueue

    /// snapshot から `SDOfflineOperation` を生成し永続化する。
    func enqueue(_ snapshot: QueuedOperationSnapshot) throws {
        let op = SDOfflineOperation(
            id: snapshot.id,
            idempotencyKey: snapshot.idempotencyKey,
            entityType: snapshot.entityType,
            operationType: snapshot.operationType,
            payload: snapshot.payload,
            priority: snapshot.priority
        )
        modelContext.insert(op)
        try modelContext.save()
    }

    // MARK: - Dequeue

    /// 次に drain すべき operation を 1 件 snapshot で返す。
    /// 並び順: priority ASC → createdAt ASC。
    /// `nextRetryAt <= now` のみ対象 (バックオフ待ち中はスキップ、デフォルトは `.distantPast` = 即時対象)。
    func dequeue(now: Date = Date()) throws -> QueuedOperationSnapshot? {
        var descriptor = FetchDescriptor<SDOfflineOperation>(
            predicate: #Predicate { op in
                op.isDeadLetter == false && op.nextRetryAt <= now
            },
            sortBy: [
                SortDescriptor(\.priority, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = 1
        guard let op = try modelContext.fetch(descriptor).first else { return nil }
        return QueuedOperationSnapshot(from: op)
    }

    // MARK: - Mark result

    /// 成功した operation を queue から削除する。
    func markSuccess(id: UUID) throws {
        let descriptor = FetchDescriptor<SDOfflineOperation>(
            predicate: #Predicate { $0.id == id }
        )
        guard let op = try modelContext.fetch(descriptor).first else {
            return  // 既に削除済の場合は no-op (drain 並列との race で冪等にする)
        }
        modelContext.delete(op)
        try modelContext.save()
    }

    /// 失敗した operation の attempt を増やし、dead letter 判定 / next retry 時刻を更新する。
    func markFailure(id: UUID, error: String, now: Date = Date()) throws {
        let descriptor = FetchDescriptor<SDOfflineOperation>(
            predicate: #Predicate { $0.id == id }
        )
        guard let op = try modelContext.fetch(descriptor).first else {
            return  // 既に削除済の場合は no-op (drain 並列との race で冪等にする)
        }
        op.attemptCount += 1
        op.lastAttemptAt = now
        op.lastError = String(error.prefix(500))  // 過大な error 文字列で DB が膨らむのを防ぐ
        if op.attemptCount >= ExponentialBackoff.maxAttempts {
            op.isDeadLetter = true
            op.nextRetryAt = .distantFuture  // 万一 isDeadLetter フィルタが外れた際の保険
        } else {
            op.nextRetryAt = ExponentialBackoff.nextRetryAt(from: now, attempt: op.attemptCount)
        }
        try modelContext.save()
    }

    // MARK: - Dead letter management

    /// dead letter になった operation の件数を返す (UI で「同期失敗」バッジ表示用)。
    func deadLetterCount() throws -> Int {
        let descriptor = FetchDescriptor<SDOfflineOperation>(
            predicate: #Predicate { $0.isDeadLetter == true }
        )
        return try modelContext.fetchCount(descriptor)
    }
}
