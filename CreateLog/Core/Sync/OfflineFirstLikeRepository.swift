import Foundation
import SwiftData

/// Offline-first Decorator for `LikeRepositoryProtocol`.
///
/// ## 戦略
/// - **like(postId:)**:
///   1. `SDLikeCache` 即時 insert (`syncStatus = .queued`) — 楽観的 UI 反映
///   2. remote 成功 → `syncStatus = .synced`
///   3. remote 失敗 → `syncService.enqueue` で queue 積む、cache は `.queued` のまま
///
/// - **unlike(postId:)**:
///   1. `SDLikeCache.isDeleted = true` (tombstone)
///   2. remote 成功 → cache row 物理削除
///   3. remote 失敗 → `syncService.enqueue` で queue 積む
///
/// - **isLiked(postId:)**:
///   1. SDLikeCache から local 判定 (offline 対応)
///   2. local に存在しない & modelContainer 無し → underlying 問合せ
///
/// ## MVP 注意
/// - 楽観的 insert は user 自身の like のみ (他 user の like count は post 側更新)
/// - counter の server-side increment trigger に依存 (Supabase function)
final class OfflineFirstLikeRepository: LikeRepositoryProtocol, @unchecked Sendable {
    private let underlying: any LikeRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    /// 現在の user UUID (Auth session から取得 or nil)。
    /// nil の場合は local cache に insert 不可 (cache が機能しないだけ、remote 呼び出しは走る)。
    private let currentUserIdProvider: @Sendable () async -> UUID?

    init(
        underlying: any LikeRepositoryProtocol,
        modelContainer: ModelContainer?,
        syncService: any SyncServiceProtocol,
        currentUserIdProvider: @Sendable @escaping () async -> UUID?
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
        self.syncService = syncService
        self.currentUserIdProvider = currentUserIdProvider
    }

    func like(postId: UUID) async throws {
        let userId = await currentUserIdProvider()
        await insertOptimisticLocal(userId: userId, postId: postId)

        do {
            try await underlying.like(postId: postId)
            await markSynced(userId: userId, postId: postId)
        } catch {
            await enqueueLike(postId: postId)
            throw error
        }
    }

    func unlike(postId: UUID) async throws {
        let userId = await currentUserIdProvider()
        await markTombstoneLocal(userId: userId, postId: postId)

        do {
            try await underlying.unlike(postId: postId)
            await purgeLocal(userId: userId, postId: postId)
        } catch {
            await enqueueUnlike(postId: postId)
            throw error
        }
    }

    func isLiked(postId: UUID) async throws -> Bool {
        // Local 判定優先 (offline でも正しく答える)
        if let userId = await currentUserIdProvider(), let container = modelContainer {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<SDLikeCache>(
                predicate: #Predicate { like in
                    like.userId == userId && like.postId == postId && like.isDeleted == false
                }
            )
            if let count = try? context.fetchCount(descriptor), count > 0 {
                return true
            }
        }
        // Fallback: underlying 問合せ
        return try await underlying.isLiked(postId: postId)
    }

    // MARK: - Local helpers

    private func insertOptimisticLocal(userId: UUID?, postId: UUID) async {
        guard let userId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDLikeCache>(
            predicate: #Predicate { like in
                like.userId == userId && like.postId == postId
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = false
            existing.syncStatus = .queued
            existing.syncedAt = Date()
        } else {
            let cache = SDLikeCache(
                userId: userId,
                postId: postId,
                createdAt: Date(),
                syncedAt: Date(),
                syncStatus: .queued
            )
            context.insert(cache)
        }
        try? context.save()
    }

    private func markSynced(userId: UUID?, postId: UUID) async {
        guard let userId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDLikeCache>(
            predicate: #Predicate { $0.userId == userId && $0.postId == postId }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.syncStatus = .synced
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    private func markTombstoneLocal(userId: UUID?, postId: UUID) async {
        guard let userId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDLikeCache>(
            predicate: #Predicate { $0.userId == userId && $0.postId == postId }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = true
            existing.syncStatus = .queued
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    private func purgeLocal(userId: UUID?, postId: UUID) async {
        guard let userId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDLikeCache>(
            predicate: #Predicate { $0.userId == userId && $0.postId == postId }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    // MARK: - Enqueue

    private func enqueueLike(postId: UUID) async {
        let payload = (try? JSONEncoder().encode(["post_id": postId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.like.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: payload,
            priority: SyncEntityType.like.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueUnlike(postId: UUID) async {
        let payload = (try? JSONEncoder().encode(["post_id": postId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.like.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.like.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}
