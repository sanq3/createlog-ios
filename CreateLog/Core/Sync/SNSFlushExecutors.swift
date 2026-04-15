import Foundation

/// T7c: SNS entity 用 `FlushExecuting` 実装群。
///
/// 5 種 (Post / Like / Follow / Comment / Notification) を 1 ファイルに集約。
/// 各 executor は `OfflineQueueActor` で dequeue された mutation を
/// underlying Supabase repository に dispatch する。
///
/// ## スコープ
/// - MVP: insert / delete / update の payload decode + underlying 呼び出し
/// - idempotencyKey は `SDOfflineOperation` 側で保持、dedup は server side
/// - conflict resolution (T7d) は scope 外
///
/// ## 設計
/// - 各 executor は 1 entity type のみ supportedEntityTypes に持つ
/// - payload decode 失敗 → `SyncError.decodingFailed` throw → dead letter 直行
/// - underlying throw → そのまま伝播、drain loop が `markFailure` → backoff

// MARK: - Post

final class PostFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.post.rawValue]

    private let postRepository: any PostRepositoryProtocol

    init(postRepository: any PostRepositoryProtocol) {
        self.postRepository = postRepository
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .insert:
            guard let post = try? JSONDecoder().decode(PostInsertDTO.self, from: snapshot.payload) else {
                throw SyncError.decodingFailed
            }
            _ = try await postRepository.insertPost(post)

        case .delete:
            guard let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload),
                  let idString = payload["id"],
                  let id = UUID(uuidString: idString) else {
                throw SyncError.decodingFailed
            }
            try await postRepository.deletePost(id: id)

        case .update:
            // T7c scope 外: post edit は v2
            return
        }
    }
}

// MARK: - Like

final class LikeFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.like.rawValue]

    private let likeRepository: any LikeRepositoryProtocol

    init(likeRepository: any LikeRepositoryProtocol) {
        self.likeRepository = likeRepository
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        guard let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload),
              let postIdString = payload["post_id"],
              let postId = UUID(uuidString: postIdString) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .insert:
            try await likeRepository.like(postId: postId)
        case .delete:
            try await likeRepository.unlike(postId: postId)
        case .update:
            return
        }
    }
}

// MARK: - Bookmark

final class BookmarkFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.bookmark.rawValue]

    private let bookmarkRepository: any BookmarkRepositoryProtocol

    init(bookmarkRepository: any BookmarkRepositoryProtocol) {
        self.bookmarkRepository = bookmarkRepository
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        guard let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload),
              let postIdString = payload["post_id"],
              let postId = UUID(uuidString: postIdString) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .insert:
            try await bookmarkRepository.bookmark(postId: postId)
        case .delete:
            try await bookmarkRepository.unbookmark(postId: postId)
        case .update:
            return
        }
    }
}

// MARK: - Follow

final class FollowFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.follow.rawValue]

    private let followRepository: any FollowRepositoryProtocol

    init(followRepository: any FollowRepositoryProtocol) {
        self.followRepository = followRepository
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        guard let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload),
              let followeeIdString = payload["followee_id"],
              let followeeId = UUID(uuidString: followeeIdString) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .insert:
            try await followRepository.follow(userId: followeeId)
        case .delete:
            try await followRepository.unfollow(userId: followeeId)
        case .update:
            return
        }
    }
}

// MARK: - Comment

final class CommentFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.comment.rawValue]

    private let commentRepository: any CommentRepositoryProtocol

    init(commentRepository: any CommentRepositoryProtocol) {
        self.commentRepository = commentRepository
    }

    /// Comment insert 用 payload 構造 (OfflineFirstCommentRepository と対応)。
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

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .insert:
            guard let payload = try? JSONDecoder().decode(CommentInsertPayload.self, from: snapshot.payload),
                  let postId = UUID(uuidString: payload.postId) else {
                throw SyncError.decodingFailed
            }
            let parentId: UUID? = payload.parentId.flatMap { UUID(uuidString: $0) }
            _ = try await commentRepository.insertComment(
                postId: postId,
                content: payload.content,
                parentId: parentId
            )

        case .delete:
            guard let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload),
                  let idString = payload["id"],
                  let id = UUID(uuidString: idString) else {
                throw SyncError.decodingFailed
            }
            try await commentRepository.deleteComment(id: id)

        case .update:
            return
        }
    }
}

// MARK: - Notification

final class NotificationFlushExecutor: FlushExecuting {
    let supportedEntityTypes: [String] = [SyncEntityType.notification.rawValue]

    private let notificationRepository: any NotificationRepositoryProtocol

    init(notificationRepository: any NotificationRepositoryProtocol) {
        self.notificationRepository = notificationRepository
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        guard let operation = SyncOperationType(rawValue: snapshot.operationType) else {
            throw SyncError.decodingFailed
        }
        switch operation {
        case .update:
            // mark as read の 2 パターン: scope=all or id=<UUID>
            if let payload = try? JSONDecoder().decode([String: String].self, from: snapshot.payload) {
                if payload["scope"] == "all" {
                    try await notificationRepository.markAllAsRead()
                } else if let idString = payload["id"], let id = UUID(uuidString: idString) {
                    try await notificationRepository.markAsRead(id: id)
                } else {
                    throw SyncError.decodingFailed
                }
            } else {
                throw SyncError.decodingFailed
            }

        case .insert, .delete:
            // 通知は server 生成 / 不可
            return
        }
    }
}
