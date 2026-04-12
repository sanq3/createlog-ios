import Foundation
import SwiftData

/// Offline-first Decorator for `NotificationRepositoryProtocol`.
///
/// ## 戦略
/// - **fetchNotifications**: remote fetch + SDNotificationCache upsert、失敗時 cache fallback
/// - **fetchUnreadCount**: local cache から isRead==false の count (offline で即答)
/// - **markAsRead**: local cache 即更新 + remote 試行 + 失敗時 enqueue
/// - **markAllAsRead**: 全 local cache update + remote + enqueue
///
/// MVP scope: realtime subscribe (recipient_id filter) は後続 task (v1.1 T7d)。
final class OfflineFirstNotificationRepository: NotificationRepositoryProtocol, @unchecked Sendable {
    private let underlying: any NotificationRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    private let currentUserIdProvider: @Sendable () async -> UUID?

    init(
        underlying: any NotificationRepositoryProtocol,
        modelContainer: ModelContainer?,
        syncService: any SyncServiceProtocol,
        currentUserIdProvider: @Sendable @escaping () async -> UUID?
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
        self.syncService = syncService
        self.currentUserIdProvider = currentUserIdProvider
    }

    // MARK: - Read

    func fetchNotifications(cursor: Date?, limit: Int) async throws -> [NotificationDTO] {
        do {
            let remote = try await underlying.fetchNotifications(cursor: cursor, limit: limit)
            await upsertCache(remote)
            return remote
        } catch {
            if let cached = await readFromCache(cursor: cursor, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func fetchUnreadCount() async throws -> Int {
        // Local cache から即答 (offline 対応、realtime 更新後も正しい値)
        if let container = modelContainer, let userId = await currentUserIdProvider() {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<SDNotificationCache>(
                predicate: #Predicate { n in
                    n.userId == userId && n.isRead == false && n.isDeleted == false
                }
            )
            if let count = try? context.fetchCount(descriptor) {
                return count
            }
        }
        return try await underlying.fetchUnreadCount()
    }

    // MARK: - Write

    func markAsRead(id: UUID) async throws {
        await markReadLocal(id: id)
        do {
            try await underlying.markAsRead(id: id)
        } catch {
            await enqueueMarkRead(id: id)
            throw error
        }
    }

    func markAllAsRead() async throws {
        await markAllReadLocal()
        do {
            try await underlying.markAllAsRead()
        } catch {
            await enqueueMarkAllRead()
            throw error
        }
    }

    // MARK: - Cache helpers

    private func upsertCache(_ notifications: [NotificationDTO]) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        for dto in notifications {
            let remoteId = dto.id
            let descriptor = FetchDescriptor<SDNotificationCache>(
                predicate: #Predicate { $0.remoteId == remoteId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.type = dto.type
                existing.actorId = dto.actorId
                existing.postId = dto.postId
                existing.message = dto.message
                existing.isRead = dto.isRead
                existing.actorDisplayName = dto.actorDisplayName
                existing.actorHandle = dto.actorHandle
                existing.syncedAt = Date()
                existing.isDeleted = false
            } else {
                let cache = SDNotificationCache(
                    remoteId: dto.id,
                    userId: dto.userId,
                    type: dto.type,
                    actorId: dto.actorId,
                    postId: dto.postId,
                    message: dto.message,
                    isRead: dto.isRead,
                    createdAt: dto.createdAt,
                    actorDisplayName: dto.actorDisplayName,
                    actorHandle: dto.actorHandle
                )
                context.insert(cache)
            }
        }
        try? context.save()
    }

    private func readFromCache(cursor: Date?, limit: Int) async -> [NotificationDTO]? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        var descriptor: FetchDescriptor<SDNotificationCache>
        if let cursor {
            descriptor = FetchDescriptor<SDNotificationCache>(
                predicate: #Predicate { n in
                    n.isDeleted == false && n.createdAt < cursor
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDNotificationCache>(
                predicate: #Predicate { n in
                    n.isDeleted == false
                },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return rows.compactMap { $0.toDTO() }
    }

    private func markReadLocal(id: UUID) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDNotificationCache>(
            predicate: #Predicate { $0.remoteId == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isRead = true
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    private func markAllReadLocal() async {
        guard let container = modelContainer, let userId = await currentUserIdProvider() else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDNotificationCache>(
            predicate: #Predicate { $0.userId == userId && $0.isRead == false }
        )
        if let rows = try? context.fetch(descriptor) {
            for row in rows {
                row.isRead = true
                row.syncedAt = Date()
            }
            try? context.save()
        }
    }

    // MARK: - Enqueue

    private func enqueueMarkRead(id: UUID) async {
        let payload = (try? JSONEncoder().encode(["id": id.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.notification.rawValue,
            operationType: SyncOperationType.update.rawValue,
            payload: payload,
            priority: SyncEntityType.notification.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueMarkAllRead() async {
        let payload = (try? JSONEncoder().encode(["scope": "all"])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.notification.rawValue,
            operationType: SyncOperationType.update.rawValue,
            payload: payload,
            priority: SyncEntityType.notification.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}

// MARK: - SDNotificationCache → NotificationDTO

private extension SDNotificationCache {
    func toDTO() -> NotificationDTO? {
        var json: [String: Any] = [
            "id": remoteId.uuidString,
            "user_id": userId.uuidString,
            "type": type,
            "is_read": isRead,
            "created_at": ISO8601DateFormatter().string(from: createdAt)
        ]
        if let actorId { json["actor_id"] = actorId.uuidString }
        if let postId { json["post_id"] = postId.uuidString }
        if let message { json["message"] = message }
        if let actorDisplayName { json["actor_display_name"] = actorDisplayName }
        if let actorHandle { json["actor_handle"] = actorHandle }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(NotificationDTO.self, from: data)
    }
}
