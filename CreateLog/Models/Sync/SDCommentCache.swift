import Foundation
import SwiftData

/// Remote `comments` テーブルの local cache。Offline-first 同期の読み出し側 cache。
///
/// ## T7c 位置付け
/// - PostDetailView の scenePhase 連動 realtime subscribe の読み取り元
/// - `OfflineFirstCommentRepository.insertComment(...)` は SDCommentCache を楽観的 insert
///   + `OfflineQueueActor.enqueue` で remote 同期
@Model
final class SDCommentCache {
    // MARK: - Primary identity

    /// Remote `comments.id`。
    var remoteId: UUID = UUID()

    /// 対象 `posts.id`。
    var postId: UUID = UUID()

    /// コメント投稿者 `profiles.id`。
    var userId: UUID = UUID()

    // MARK: - Core fields

    var content: String = ""
    var parentCommentId: UUID? = nil
    var createdAt: Date = Date()

    // MARK: - Author denormalized

    var authorDisplayName: String? = nil
    var authorHandle: String? = nil

    // MARK: - Cache metadata

    var syncedAt: Date = Date()
    var isDeleted: Bool = false
    var updatedAtRemote: Date = Date()

    init(
        remoteId: UUID,
        postId: UUID,
        userId: UUID,
        content: String,
        parentCommentId: UUID? = nil,
        createdAt: Date = Date(),
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        updatedAtRemote: Date = Date()
    ) {
        self.remoteId = remoteId
        self.postId = postId
        self.userId = userId
        self.content = content
        self.parentCommentId = parentCommentId
        self.createdAt = createdAt
        self.authorDisplayName = authorDisplayName
        self.authorHandle = authorHandle
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
        self.updatedAtRemote = updatedAtRemote
    }
}
