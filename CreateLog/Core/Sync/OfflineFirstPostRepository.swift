import Foundation
import SwiftData

/// Offline-first Decorator for `PostRepositoryProtocol`.
///
/// ## 戦略
/// - **Read (fetchFeed / fetchFollowingFeed)**:
///   1. remote fetch を試行
///   2. 成功 → `SDPostCache` に upsert、remote 結果を return
///   3. 失敗 (network 不可 等) → `SDPostCache` から最新 N 件を fallback 返却
///   → Stale-While-Revalidate (SWR) の下位実装。View 層は @Query で cache を購読可能。
///
/// - **Write (insertPost)**:
///   1. remote 成功 → `SDPostCache` に upsert + success
///   2. remote 失敗 → `syncService.enqueue` で OfflineQueue に積む + tombstone local insert
///      (この場合 return DTO は暫定 local DTO、remote id は後続 flush で確定)
///
/// - **Delete (deletePost)**:
///   1. SDPostCache.isDeleted = true (tombstone、@Query は isDeleted==false で filter)
///   2. remote 直接 delete 試行 or enqueue
///
/// ## 注意
/// - ModelContainer 未注入時 (preview / test) は underlying のみ使用、cache 無効化
/// - MVP scope: read fallback + write tombstone のみ。SWR polling は ViewModel 層で実装
final class OfflineFirstPostRepository: PostRepositoryProtocol, @unchecked Sendable {
    private let underlying: any PostRepositoryProtocol
    private let modelContainer: ModelContainer?
    private let syncService: any SyncServiceProtocol
    /// 2026-04-16: feed 取得成功時に post.author basic を SDProfileCache に先行書き込みするため保持。
    /// preview 等で nil の場合は precache を skip。
    private let profileRepository: (any ProfileRepositoryProtocol)?

    init(
        underlying: any PostRepositoryProtocol,
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

    func fetchFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        do {
            let remote = try await underlying.fetchFeed(cursor: cursor, limit: limit)
            await upsertCache(remote)
            precacheAuthors(from: remote)
            return remote
        } catch {
            // Network 失敗 → cache fallback
            if let cached = await readFromCache(cursor: cursor, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func fetchFollowingFeed(cursor: Date?, limit: Int) async throws -> [PostDTO] {
        do {
            let remote = try await underlying.fetchFollowingFeed(cursor: cursor, limit: limit)
            await upsertCache(remote)
            precacheAuthors(from: remote)
            return remote
        } catch {
            if let cached = await readFromCache(cursor: cursor, limit: limit), !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    func fetchUserPosts(userId: UUID, cursor: Date?, limit: Int) async throws -> [PostDTO] {
        // プロフィール画面用。remote 直接 fetch + 成功時 upsert。
        // cache fallback はしない (他人プロフィールを cache しても混乱の元)。
        let remote = try await underlying.fetchUserPosts(userId: userId, cursor: cursor, limit: limit)
        await upsertCache(remote)
        precacheAuthors(from: remote)
        return remote
    }

    /// Feed precache (Bluesky pattern): 各 post の author basic を SDProfileCache に先行書き込み。
    /// - feed JOIN で取れなかった post は author* が nil → precacheBasic 側の all-nil guard で no-op
    /// - 後で UserProfileView 遷移時に cache hit → spinner ゼロ描画
    private func precacheAuthors(from posts: [PostDTO]) {
        guard let profileRepository else { return }
        for post in posts {
            profileRepository.precacheBasic(
                userId: post.userId,
                handle: post.authorHandle,
                displayName: post.authorDisplayName,
                avatarUrl: post.authorAvatarUrl
            )
        }
    }

    // MARK: - Write

    func insertPost(_ post: PostInsertDTO) async throws -> PostDTO {
        do {
            let remote = try await underlying.insertPost(post)
            await upsertCache([remote])
            return remote
        } catch {
            // Offline insert: payload を enqueue
            await enqueueInsert(post)
            throw error
        }
    }

    func deletePost(id: UUID) async throws {
        await markTombstone(id: id)
        do {
            try await underlying.deletePost(id: id)
        } catch {
            await enqueueDelete(id: id)
            throw error
        }
    }

    func uploadPostMedia(thumbData: Data, fullData: Data, contentType: String, width: Int, height: Int) async throws -> PostMediaItem {
        // upload はオフライン queue 対象外 (画像サイズが大きく queue payload に適さない、
        // かつ投稿本体の前提条件なので失敗時は compose 画面でリトライする UX が自然)。
        try await underlying.uploadPostMedia(
            thumbData: thumbData,
            fullData: fullData,
            contentType: contentType,
            width: width,
            height: height
        )
    }

    // MARK: - Cache helpers

    private func upsertCache(_ posts: [PostDTO]) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        for dto in posts {
            let remoteId = dto.id
            let descriptor = FetchDescriptor<SDPostCache>(
                predicate: #Predicate { $0.remoteId == remoteId }
            )
            if let existing = try? context.fetch(descriptor).first {
                existing.content = dto.content
                existing.setMedia(dto.media)
                existing.visibility = dto.visibility
                existing.likesCount = dto.likesCount
                existing.commentsCount = dto.commentsCount
                existing.repostsCount = dto.repostsCount
                existing.authorDisplayName = dto.authorDisplayName
                existing.authorHandle = dto.authorHandle
                existing.authorAvatarUrl = dto.authorAvatarUrl
                existing.syncedAt = Date()
                existing.isDeleted = false
                existing.updatedAtRemote = dto.updatedAt
            } else {
                let cache = SDPostCache(
                    remoteId: dto.id,
                    userId: dto.userId,
                    content: dto.content,
                    media: dto.media,
                    visibility: dto.visibility,
                    likesCount: dto.likesCount,
                    commentsCount: dto.commentsCount,
                    repostsCount: dto.repostsCount,
                    createdAt: dto.createdAt,
                    authorDisplayName: dto.authorDisplayName,
                    authorHandle: dto.authorHandle,
                    authorAvatarUrl: dto.authorAvatarUrl,
                    syncedAt: Date(),
                    updatedAtRemote: dto.updatedAt
                )
                context.insert(cache)
            }
        }
        try? context.save()
    }

    private func readFromCache(cursor: Date?, limit: Int) async -> [PostDTO]? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        var descriptor: FetchDescriptor<SDPostCache>
        if let cursor {
            descriptor = FetchDescriptor<SDPostCache>(
                predicate: #Predicate { $0.isDeleted == false && $0.createdAt < cursor },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<SDPostCache>(
                predicate: #Predicate { $0.isDeleted == false },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        descriptor.fetchLimit = limit
        guard let rows = try? context.fetch(descriptor) else { return nil }
        return rows.compactMap { $0.toDTO() }
    }

    private func markTombstone(id: UUID) async {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDPostCache>(
            predicate: #Predicate { $0.remoteId == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.isDeleted = true
            existing.syncedAt = Date()
            try? context.save()
        }
    }

    // MARK: - Enqueue helpers

    private func enqueueInsert(_ post: PostInsertDTO) async {
        guard let payload = try? JSONEncoder().encode(post) else { return }
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.post.rawValue,
            operationType: SyncOperationType.insert.rawValue,
            payload: payload,
            priority: SyncEntityType.post.drainPriority
        )
        await syncService.enqueue(snapshot)
    }

    private func enqueueDelete(id: UUID) async {
        let payload = (try? JSONEncoder().encode(["id": id.uuidString])) ?? Data()
        let snapshot = QueuedOperationSnapshot(
            entityType: SyncEntityType.post.rawValue,
            operationType: SyncOperationType.delete.rawValue,
            payload: payload,
            priority: SyncEntityType.post.drainPriority
        )
        await syncService.enqueue(snapshot)
    }
}

// MARK: - SDPostCache → PostDTO

private extension SDPostCache {
    func toDTO() -> PostDTO? {
        // media_urls は [PostMediaItem] を JSON object 配列として埋め込む。
        let mediaJSON: Any = {
            guard let encoded = try? JSONEncoder().encode(media),
                  let obj = try? JSONSerialization.jsonObject(with: encoded) else {
                return [] as [Any]
            }
            return obj
        }()
        let json: [String: Any] = [
            "id": remoteId.uuidString,
            "user_id": userId.uuidString,
            "content": content,
            "media_urls": mediaJSON,
            "visibility": visibility,
            "likes_count": likesCount,
            "comments_count": commentsCount,
            "reposts_count": repostsCount,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAtRemote),
            "author_display_name": authorDisplayName as Any,
            "author_handle": authorHandle as Any,
            "author_avatar_url": authorAvatarUrl as Any
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: json.compactMapValues { $0 is NSNull ? nil : $0 }) else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(PostDTO.self, from: data)
    }
}
