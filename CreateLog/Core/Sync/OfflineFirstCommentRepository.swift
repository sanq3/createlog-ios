import Foundation
import SwiftData

/// Offline-first Decorator for `CommentRepositoryProtocol`.
///
/// ## 戦略
/// - **fetchComments**: remote fetch + SDCommentCache upsert、失敗時 cache fallback
/// - **insertComment**: remote 成功 → cache upsert + return、失敗時 enqueue
/// - **deleteComment**: tombstone + remote 試行 + enqueue fallback
///
/// MVP scope: realtime subscribe は T7c 後続で追加 (PostDetailViewModel 側)。
final class OfflineFirstCommentRepository: CommentRepositoryProtocol, @unchecked Sendable {
    private let underlying: any CommentRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    /// 2026-04-16: feed-precache pattern 同型。comment 取得時に author basic を SDProfileCache へ書き込み。
    private let profileRepository: (any ProfileRepositoryProtocol)?

    init(
        underlying: any CommentRepositoryProtocol,
        modelContainer: ModelContainer?,
        syncService: any SyncServiceProtocol,
        profileRepository: (any ProfileRepositoryProtocol)? = nil
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
        self.syncService = syncService
        self.profileRepository = profileRepository
    }

    // MARK: - Read

    func fetchComments(postId: UUID, cursor: Date?, limit: Int) async throws -> [CommentDTO] {
        do {
            let remote = try await underlying.fetchComments(postId: postId, cursor: cursor, limit: limit)
            await upsertCache(remote)
            precacheAuthors(from: remote)
            return remote
        } catch {
            if let cached = await readFromCache(postId: postId, cursor: cursor, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    private func precacheAuthors(from comments: [CommentDTO]) {
        guard let profileRepository else { return }
        for c in comments {
            profileRepository.precacheBasic(
                userId: c.userId,
                handle: c.authorHandle,
                displayName: c.authorDisplayName,
                avatarUrl: c.authorAvatarUrl
            )
        }
    }

    // MARK: - Write

    func insertComment(postId: UUID, content: String, parentId: UUID?) async throws -> CommentDTO {
        do {
            let remote = try await underlying.insertComment(postId: postId, content: content, parentId: parentId)
            await upsertCache([remote])
            return remote
        } catch {
            await enqueueInsert(postId: postId, content: content, parentId: parentId)
            throw error
        }
    }

    func deleteComment(id: UUID) async throws {
        await markTombstone(id: id)
        do {
            try await underlying.deleteComment(id: id)
        } catch {
            await enqueueDelete(id: id)
            throw error
        }
    }

    // MARK: - Cache helpers

    private func upsertCache(_ comments: [CommentDTO]) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        for dto in comments {
            let remoteId = dto.id
            let descriptor = FetchDescriptor<SDCommentCache>(
                predicate: #Predicate { $0.remoteId == remoteId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.content = dto.content
                existing.parentCommentId = dto.parentCommentId
                existing.authorDisplayName = dto.authorDisplayName
                existing.authorHandle = dto.authorHandle
                existing.syncedAt = Date()
                existing.isDeleted = false
            } else {
                let cache = SDCommentCache(
                    remoteId: dto.id,
                    postId: dto.postId,
                    userId: dto.userId,
                    content: dto.content,
                    parentCommentId: dto.parentCommentId,
                    createdAt: dto.createdAt,
                    authorDisplayName: dto.authorDisplayName,
                    authorHandle: dto.authorHandle
                )
                context.insert(cache)
            }
        }
        try? context.save()
    }

    private func readFromCache(postId: UUID, cursor: Date?, limit: Int) async -> [CommentDTO]? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        var descriptor: FetchDescriptor<SDCommentCache>
        if let cursor {
            descriptor = FetchDescriptor<SDCommentCache>(
                predicate: #Predicate { c in
                    c.postId == postId && c.isDeleted == false && c.createdAt > cursor
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        } else {
            descriptor = FetchDescriptor<SDCommentCache>(
                predicate: #Predicate { c in
                    c.postId == postId && c.isDeleted == false
                },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
        }
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return rows.compactMap { $0.toDTO() }
    }

    private func markTombstone(id: UUID) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDCommentCache>(
            predicate: #Predicate { $0.remoteId == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = true
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    // MARK: - Enqueue

    private struct CommentInsertPayload: Codable {
        let postId: String
        let content: String
        let parentId: String?

        enum CodingKeys: String, CodingKey {
            case postId = "post_id"
            case content
            case parentId = "parent_id"
        }
    }

    private func enqueueInsert(postId: UUID, content: String, parentId: UUID?) async {
        let payload = CommentInsertPayload(
            postId: postId.uuidString,
            content: content,
            parentId: parentId?.uuidString
        )
        let data = (try? JSONEncoder().encode(payload)) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.comment.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: data,
            priority: SyncEntityType.comment.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueDelete(id: UUID) async {
        let payload = (try? JSONEncoder().encode(["id": id.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.comment.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.comment.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}

// MARK: - SDCommentCache → CommentDTO

private extension SDCommentCache {
    func toDTO() -> CommentDTO? {
        var json: [String: Any] = [
            "id": remoteId.uuidString,
            "post_id": postId.uuidString,
            "user_id": userId.uuidString,
            "content": content,
            "created_at": ISO8601DateFormatter().string(from: createdAt)
        ]
        if let parentCommentId {
            json["parent_comment_id"] = parentCommentId.uuidString
        }
        if let authorDisplayName {
            json["author_display_name"] = authorDisplayName
        }
        if let authorHandle {
            json["author_handle"] = authorHandle
        }
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(CommentDTO.self, from: data)
    }
}
