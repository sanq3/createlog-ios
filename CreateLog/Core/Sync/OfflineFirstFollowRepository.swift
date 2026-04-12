import Foundation
import SwiftData

/// Offline-first Decorator for `FollowRepositoryProtocol`.
///
/// ## 戦略
/// Like と同じ pattern: 楽観的 cache insert + remote 試行 + 失敗時 enqueue。
/// isFollowing(userId:) は local cache 優先判定で offline 対応。
/// fetchCounts(userId:) は集計なので remote 直接呼び出し (cache 困難)。
final class OfflineFirstFollowRepository: FollowRepositoryProtocol, @unchecked Sendable {
    private let underlying: any FollowRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    private let currentUserIdProvider: @Sendable () async -> UUID?

    init(
        underlying: any FollowRepositoryProtocol,
        modelContainer: ModelContainer?,
        syncService: any SyncServiceProtocol,
        currentUserIdProvider: @Sendable @escaping () async -> UUID?
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
        self.syncService = syncService
        self.currentUserIdProvider = currentUserIdProvider
    }

    func follow(userId: UUID) async throws {
        let followerId = await currentUserIdProvider()
        await insertOptimisticLocal(followerId: followerId, followeeId: userId)
        do {
            try await underlying.follow(userId: userId)
            await markSynced(followerId: followerId, followeeId: userId)
        } catch {
            await enqueueFollow(followeeId: userId)
            throw error
        }
    }

    func unfollow(userId: UUID) async throws {
        let followerId = await currentUserIdProvider()
        await markTombstoneLocal(followerId: followerId, followeeId: userId)
        do {
            try await underlying.unfollow(userId: userId)
            await purgeLocal(followerId: followerId, followeeId: userId)
        } catch {
            await enqueueUnfollow(followeeId: userId)
            throw error
        }
    }

    func isFollowing(userId: UUID) async throws -> Bool {
        if let followerId = await currentUserIdProvider(), let container = modelContainer {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<SDFollowCache>(
                predicate: #Predicate { f in
                    f.followerId == followerId && f.followeeId == userId && f.isDeleted == false
                }
            )
            if let count = try? context.fetchCount(descriptor), count > 0 {
                return true
            }
        }
        return try await underlying.isFollowing(userId: userId)
    }

    func fetchCounts(userId: UUID) async throws -> (followers: Int, following: Int) {
        // 集計は remote のみ (local cache では all-rows が無いと正確でない)
        try await underlying.fetchCounts(userId: userId)
    }

    // MARK: - Local helpers

    private func insertOptimisticLocal(followerId: UUID?, followeeId: UUID) async {
        guard let followerId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDFollowCache>(
            predicate: #Predicate { f in
                f.followerId == followerId && f.followeeId == followeeId
            }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = false
            existing.syncStatus = .queued
            existing.syncedAt = Date()
        } else {
            let cache = SDFollowCache(
                followerId: followerId,
                followeeId: followeeId,
                createdAt: Date(),
                syncStatus: .queued
            )
            context.insert(cache)
        }
        try? context.save()
    }

    private func markSynced(followerId: UUID?, followeeId: UUID) async {
        guard let followerId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDFollowCache>(
            predicate: #Predicate { $0.followerId == followerId && $0.followeeId == followeeId }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.syncStatus = .synced
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    private func markTombstoneLocal(followerId: UUID?, followeeId: UUID) async {
        guard let followerId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDFollowCache>(
            predicate: #Predicate { $0.followerId == followerId && $0.followeeId == followeeId }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = true
            existing.syncStatus = .queued
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    private func purgeLocal(followerId: UUID?, followeeId: UUID) async {
        guard let followerId, let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDFollowCache>(
            predicate: #Predicate { $0.followerId == followerId && $0.followeeId == followeeId }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    // MARK: - Enqueue

    private func enqueueFollow(followeeId: UUID) async {
        let payload = (try? JSONEncoder().encode(["followee_id": followeeId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.follow.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: payload,
            priority: SyncEntityType.follow.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueUnfollow(followeeId: UUID) async {
        let payload = (try? JSONEncoder().encode(["followee_id": followeeId.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.follow.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.follow.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}
