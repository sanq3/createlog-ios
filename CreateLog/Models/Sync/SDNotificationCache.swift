import Foundation
import SwiftData

/// Remote `notifications` テーブルの local cache。Offline-first 同期の読み出し側 cache。
///
/// ## T7c 位置付け
/// - NotificationView での realtime subscribe 読み取り元
/// - insert はサーバー生成、local では read-only (mark-as-read のみ write)
/// - `OfflineFirstNotificationRepository` は read = SDNotificationCache、
///   write = `markAsRead(id:)` の 1 種のみ offline queue 経由
@Model
final class SDNotificationCache {
    // MARK: - Primary identity

    /// Remote `notifications.id`。
    var remoteId: UUID = UUID()

    /// 受信 user `profiles.id` (= 現在の user)。RLS filter 用。
    var userId: UUID = UUID()

    // MARK: - Core fields

    var type: String = "system"
    var actorId: UUID? = nil
    var postId: UUID? = nil
    var message: String? = nil
    var isRead: Bool = false
    var createdAt: Date = Date()

    // MARK: - Actor denormalized (JOIN profile 回避)

    var actorDisplayName: String? = nil
    var actorHandle: String? = nil

    // MARK: - Cache metadata

    var syncedAt: Date = Date()
    var isDeleted: Bool = false

    init(
        remoteId: UUID,
        userId: UUID,
        type: String,
        actorId: UUID? = nil,
        postId: UUID? = nil,
        message: String? = nil,
        isRead: Bool = false,
        createdAt: Date = Date(),
        actorDisplayName: String? = nil,
        actorHandle: String? = nil,
        syncedAt: Date = Date(),
        isDeleted: Bool = false
    ) {
        self.remoteId = remoteId
        self.userId = userId
        self.type = type
        self.actorId = actorId
        self.postId = postId
        self.message = message
        self.isRead = isRead
        self.createdAt = createdAt
        self.actorDisplayName = actorDisplayName
        self.actorHandle = actorHandle
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
    }
}
