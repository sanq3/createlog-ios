import Foundation
import SwiftData

/// Offline-first Decorator for `LogRepositoryProtocol`.
///
/// ## 戦略
/// - **Read (fetchLogs)**: remote fetch → SDLogCache upsert、失敗時 cache fallback (SWR)
/// - **Insert**: remote 成功 → cache upsert + return、失敗 → enqueue
/// - **Update**: remote 成功 → cache upsert + return、失敗 → enqueue
/// - **Delete**: tombstone → remote → 失敗時 enqueue
final class OfflineFirstLogRepository: LogRepositoryProtocol, @unchecked Sendable {
    private let underlying: any LogRepositoryProtocol
    private let cacheWriter: LogCacheWriter
    private let modelContainer: ModelContainer
    private let syncService: any SyncServiceProtocol

    init(
        underlying: any LogRepositoryProtocol,
        cacheWriter: LogCacheWriter,
        modelContainer: ModelContainer,
        syncService: any SyncServiceProtocol
    ) {
        self.underlying = underlying
        self.cacheWriter = cacheWriter
        self.modelContainer = modelContainer
        self.syncService = syncService
    }

    // MARK: - Read

    func fetchLogs(for date: Date) async throws -> [LogDTO] {
        do {
            let remote = try await underlying.fetchLogs(for: date)
            try? await cacheWriter.upsert(remote)
            return remote
        } catch {
            if let cached = readFromCache(for: date), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func fetchLogs(from start: Date, to end: Date) async throws -> [LogDTO] {
        do {
            let remote = try await underlying.fetchLogs(from: start, to: end)
            try? await cacheWriter.upsert(remote)
            return remote
        } catch {
            if let cached = readFromCache(from: start, to: end), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    // MARK: - Write

    func insertLog(_ log: LogInsertDTO) async throws -> LogDTO {
        do {
            let remote = try await underlying.insertLog(log)
            try? await cacheWriter.upsert([remote])
            return remote
        } catch {
            await enqueueInsert(log)
            throw error
        }
    }

    func updateLog(_ update: LogUpdateDTO) async throws -> LogDTO {
        do {
            let remote = try await underlying.updateLog(update)
            try? await cacheWriter.upsert([remote])
            return remote
        } catch {
            await enqueueUpdate(update)
            throw error
        }
    }

    func deleteLog(id: UUID) async throws {
        try? await cacheWriter.markTombstone(remoteId: id)
        do {
            try await underlying.deleteLog(id: id)
        } catch {
            await enqueueDelete(id: id)
            throw error
        }
    }

    // MARK: - Cache read (local ModelContext)

    private func readFromCache(for date: Date) -> [LogDTO]? {
        let context = ModelContext(modelContainer)
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd = dayStart.addingTimeInterval(86400)
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { log in
                log.isDeleted == false &&
                log.startedAt >= dayStart &&
                log.startedAt < dayEnd
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return rows.map { $0.toDTO() }
    }

    private func readFromCache(from start: Date, to end: Date) -> [LogDTO]? {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<SDLogCache>(
            predicate: #Predicate { log in
                log.isDeleted == false &&
                log.startedAt >= start &&
                log.startedAt < end
            },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return rows.map { $0.toDTO() }
    }

    // MARK: - Enqueue

    private func enqueueInsert(_ log: LogInsertDTO) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(log) else { return }
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.log.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: payload,
            priority: SyncEntityType.log.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueUpdate(_ update: LogUpdateDTO) async {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let payload = try? encoder.encode(update) else { return }
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.log.rawValue,
            operationType: SyncOperationType.update.rawValue,
            payload: payload,
            priority: SyncEntityType.log.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueDelete(id: UUID) async {
        guard let payload = try? JSONEncoder().encode(["id": id.uuidString]) else { return }
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.log.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.log.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}

// MARK: - SDLogCache → LogDTO

private extension SDLogCache {
    func toDTO() -> LogDTO {
        let json: [String: Any] = [
            "id": remoteId.uuidString,
            "user_id": userId.uuidString,
            "title": title,
            "category_id": categoryId.uuidString,
            "started_at": ISO8601DateFormatter().string(from: startedAt),
            "ended_at": ISO8601DateFormatter().string(from: endedAt ?? startedAt),
            "duration_minutes": durationMinutes,
            "is_timer": isTimer,
            "created_at": ISO8601DateFormatter().string(from: syncedAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAtRemote)
        ]
        // Force unwrap は safe: 全フィールドが non-nil 確定
        let data = try! JSONSerialization.data(withJSONObject: json)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try! decoder.decode(LogDTO.self, from: data)
    }
}
