import Foundation
import SwiftData

/// Offline-first Decorator for `BookmarkRepositoryProtocol`。
/// OfflineFirstLikeRepository と完全同型の pattern で、`SDBookmarkCache` を cache として使う。
///
/// ## 戦略
/// - **bookmark(postId:)**:
///   1. `SDBookmarkCache` 即時 insert (`syncStatus = .queued`) — 楽観的 UI 反映
///   2. remote 成功 → `syncStatus = .synced`
///   3. remote 失敗 → `syncService.enqueue` で queue 積む、cache は `.queued` のまま
///
/// - **unbookmark(postId:)**:
///   1. `SDBookmarkCache.isDeleted = true` (tombstone)
///   2. remote 成功 → cache row 物理削除
///   3. remote 失敗 → `syncService.enqueue` で queue 積む
///
/// - **isBookmarked(postId:)**:
///   1. SDBookmarkCache から local 判定 (offline 対応)
///   2. local に存在しない & modelContainer 無し → underlying 問合せ
///
/// - **fetchBookmarked(cursor:limit:)**: underlying 直接、cache は更新しない
///   (一覧は毎回 remote 最新を取る方が UX 良い)
final class OfflineFirstBookmarkRepository: BookmarkRepositoryProtocol, @unchecked Sendable {
    private let underlying: any BookmarkRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    private let currentUserIdProvider: @Sendable () async -> UUID?

    init(
        underlying: any BookmarkRepositoryProtocol,
        modelContainer: ModelContainer?,
        syncService: any SyncServiceProtocol,
        currentUserIdProvider: @Sendable @escaping () async -> UUID?
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
        self.syncService = syncService
        self.currentUserIdProvider = currentUserIdProvider
    }

    func bookmark(postId: UUID) async throws {
        let userId = await currentUserIdProvider()
        await insertOptimisticLocal(userId: userId, postId: postId)

        do {
            try await underlying.bookmark(postId: postId)
            await markSynced(userId: userId, postId: postId)
        } catch {
            await enqueueBookmark(postId: postId)
            throw error
        }
    }

    func unbookmark(postId: UUID) async throws {
        let userId = await currentUserIdProvider()
        await markTombstoneLocal(userId: userId, postId: postId)

        do {
            try await underlying.unbookmark(postId: postId)
            await purgeLocal(userId: userId, postId: postId)
        } catch {
            await enqueueUnbookmark(postId: postId)
            throw error
        }
    }

    func isBookmarked(postId: UUID) async throws -> Bool {
        if let userId = await currentUserIdProvider(), let container = modelContainer {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<SDBookmarkCache>(
                predicate: #Predicate { b in
                    b.userId == userId && b.postId == postId && b.isDeleted == false
                }
            )
            if let count = try? context.fetchCount(descriptor), count > 0 {
                return true
            }
        }
        return try await underlying.isBookmarked(postId: postId)
    }

    func fetchBookmarked(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        try await underlying.fetchBookmarked(cursor: cursor, limit: limit)
    }

    // MARK: - Local helpers

    private func insertOptimisticLocal(userId: UUID?, postId: UUID) async {
        guard let userId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDBookmarkCache>(
            predicate: #Predicate { b in
                b.userId == userId && b.postId == postId
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = false
            existing.syncStatus = .queued
            existing.syncedAt = Date()
        } else {
            let cache = SDBookmarkCache(
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
        let descriptor = FetchDescriptor<SDBookmarkCache>(
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
        let descriptor = FetchDescriptor<SDBookmarkCache>(
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
        let descriptor = FetchDescriptor<SDBookmarkCache>(
            predicate: #Predicate { $0.userId == userId && $0.postId == postId }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    // MARK: - Enqueue

    private func enqueueBookmark(postId: UUID) async {
        let payload = (try? JSONEncoder().encode(["post_id": postId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.bookmark.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: payload,
            priority: SyncEntityType.bookmark.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueUnbookmark(postId: UUID) async {
        let payload = (try? JSONEncoder().encode(["post_id": postId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.bookmark.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.bookmark.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}
