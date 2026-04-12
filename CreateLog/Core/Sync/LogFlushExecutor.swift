import Foundation

/// `SyncEntityType.log` 用の `FlushExecuting` 具象実装。
///
/// `LogRepositoryProtocol` (underlying SupabaseLogRepository を想定) と
/// `LogCacheWriter` を注入し、queue から取り出した snapshot を remote に flush する。
///
/// ## T7b 実装範囲
/// - `SyncOperationType` rawValue バリデーション (typo / 旧 version からの fallback)
/// - `insert`: `LogInsertDTO` を decode → `logRepository.insertLog(...)` → 成功時 cache upsert
/// - `update`: `LogUpdateDTO` を decode → `logRepository.updateLog(...)` → 成功時 cache upsert
/// - `delete`: payload から `id` を decode → `logRepository.deleteLog(id:)` → tombstone 化
///
/// ## 注意
/// - `logRepository` は **underlying** な repository (SupabaseLogRepository) を渡すこと。
///   `OfflineFirstLogRepository` を渡すと flush 失敗時に再 enqueue される無限ループになる。
/// - `LogCacheWriter` は `SDLogCache` schema を含む `ModelContainer` で構築されている前提。
final class LogFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.log.rawValue]

    private let logRepository: any LogRepositoryProtocol
    private let cacheWriter: LogCacheWriter
    private let decoder: JSONDecoder

    init(logRepository: any LogRepositoryProtocol, cacheWriter: LogCacheWriter) {
        self.logRepository = logRepository
        self.cacheWriter = cacheWriter
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        self.decoder = d
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }

        switch operation {
        case .insert:
            let dto: LogInsertDTO
            do {
                dto = try decoder.decode(LogInsertDTO.self, from: snapshot.payload)
            } catch {
                throw SyncError.decodingFailed
            }
            let inserted = try await logRepository.insertLog(dto)
            try await cacheWriter.upsert([inserted])

        case .update:
            let dto: LogUpdateDTO
            do {
                dto = try decoder.decode(LogUpdateDTO.self, from: snapshot.payload)
            } catch {
                throw SyncError.decodingFailed
            }
            let updated = try await logRepository.updateLog(dto)
            try await cacheWriter.upsert([updated])

        case .delete:
            let id: UUID
            do {
                let payload = try decoder.decode(DeletePayload.self, from: snapshot.payload)
                id = payload.id
            } catch {
                throw SyncError.decodingFailed
            }
            try await logRepository.deleteLog(id: id)
            try await cacheWriter.markTombstone(remoteId: id)
        }
    }

    /// delete operation の queue payload format (`{"id": "..."}` JSON)。
    private struct DeletePayload: Decodable {
        let id: UUID
    }
}
