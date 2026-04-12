import Foundation
import SwiftData

/// `SDLogCache` への排他書き込みを保証する `@ModelActor`。
///
/// ## 責務
/// - **upsert**: remote LogDTO 群を local cache に反映する (LWW 比較 by `updatedAtRemote`)
/// - **markTombstone**: remote 削除された log を `isDeleted = true` で論理削除
/// - **delete**: hard delete (test 用 / cache compaction)
///
/// ## なぜ Actor 化するか
/// SwiftData の `ModelContext` は thread-safe ではないため、cache 書き込みは
/// 必ずこの actor 経由にする。`LogFlushExecutor` (drain loop 内) と
/// `OfflineFirstLogRepository` (read fallback 経路) の両方から呼ばれる。
///
/// ## LWW (Last Write Wins) 戦略
/// 既存 cache に同じ `remoteId` が存在する場合、`SyncDateRounding.isNewer` で
/// `dto.updatedAt > existing.updatedAtRemote` の場合のみ上書きする。
/// 1ms 以下の精度差は無視 (PostgREST timestamptz と Swift Date の往復で揺らぐため)。
///
/// ## ModelContainer schema 要件
/// - 呼び出し側 (DI) が `SDLogCache` を含む schema で初期化した container を渡すこと。
/// - test では in-memory container を `LogCacheWriter(modelContainer:)` に注入する。
@ModelActor
actor LogCacheWriter {

    // MARK: - Upsert

    /// `LogDTO` 群を `SDLogCache` に upsert する。
    /// LWW 比較で remote が新しい場合のみ上書き、それ以外は no-op。
    /// `isDeleted == true` の row も復活 (cache 整合性のため)。
    func upsert(_ logs: [LogDTO]) throws {
        for dto in logs {
            try upsertOne(dto)
        }
        try modelContext.save()
    }

    /// 単一 `LogDTO` を upsert する (内部用、save() 自体は呼び出し側で 1 回まとめる)。
    private func upsertOne(_ dto: LogDTO) throws {
        let remoteId = dto.id
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            // LWW: remote が新しい場合のみ上書き
            guard SyncDateRounding.isNewer(dto.updatedAt, than: existing.updatedAtRemote) else {
                return
            }
            existing.userId = dto.userId
            existing.title = dto.title
            existing.categoryId = dto.categoryId
            existing.startedAt = dto.startedAt
            existing.endedAt = dto.endedAt
            existing.durationMinutes = dto.durationMinutes
            existing.isTimer = dto.isTimer
            existing.syncedAt = Date()
            existing.isDeleted = false
            existing.updatedAtRemote = dto.updatedAt
        } else {
            let cache = SDLogCache(
                remoteId: dto.id,
                userId: dto.userId,
                title: dto.title,
                categoryId: dto.categoryId,
                startedAt: dto.startedAt,
                endedAt: dto.endedAt,
                durationMinutes: dto.durationMinutes,
                isTimer: dto.isTimer,
                syncedAt: Date(),
                isDeleted: false,
                updatedAtRemote: dto.updatedAt
            )
            modelContext.insert(cache)
        }
    }

    // MARK: - Tombstone

    /// remote 削除を反映: `isDeleted = true` を立てるだけ (hard delete はしない)。
    /// View 層は `isDeleted == false` で filter する想定。
    func markTombstone(remoteId: UUID) throws {
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        guard let existing = try modelContext.fetch(descriptor).first else {
            return  // cache に無ければ no-op (既に消えている)
        }
        existing.isDeleted = true
        existing.syncedAt = Date()
        try modelContext.save()
    }

    // MARK: - Hard delete (test / compaction)

    /// hard delete: test での状態リセットや cache compaction で使う。
    /// 本番 drain 経路では `markTombstone` を使う。
    func delete(remoteId: UUID) throws {
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        guard let existing = try modelContext.fetch(descriptor).first else { return }
        modelContext.delete(existing)
        try modelContext.save()
    }

    // MARK: - Read (test 用 helper)

    /// 単一 cache row の存在確認 (test 用)。
    func contains(remoteId: UUID) throws -> Bool {
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        return try modelContext.fetchCount(descriptor) > 0
    }
}
