import Foundation
import SwiftData

/// Remote `likes` テーブルの local cache。Offline-first 同期の読み出し側 cache。
///
/// ## T7c 位置付け
/// - like/unlike のオフライン操作を楽観的に反映する役割
/// - `OfflineFirstLikeRepository.like(postId:)` が SDLikeCache を即時 insert (syncStatus = .pending)
///   と同時に `OfflineQueueActor.enqueue` で remote 同期
/// - 失敗時は SDLikeCache を rollback (isDeleted = true)
///
/// ## 主キー設計
/// remote 側の `likes.id` は UUID 自動採番。local 側は暫定的に自己生成 UUID で採番し、
/// remote 往復後に真の id で upsert する (idempotencyKey で重複防止)。
@Model
final class SDLikeCache {
    // MARK: - Primary identity

    /// Remote `likes.id` (UUID PK、初期は local 生成、insert 後 remote id で上書き)。
    var remoteId: UUID = UUID()

    /// いいねした user `profiles.id`。
    var userId: UUID = UUID()

    /// いいね対象 `posts.id`。
    var postId: UUID = UUID()

    var createdAt: Date = Date()

    // MARK: - Cache metadata

    var syncedAt: Date = Date()

    /// Tombstone フラグ。unlike 時に true (物理削除は sync flush 後)。
    var isDeleted: Bool = false

    /// 同期状態 (.pending / .syncing / .synced / .failed)。
    /// `SyncStatus` を文字列で保持 (SwiftData 制約)。
    var syncStatusRaw: String = SyncStatus.synced.rawValue

    init(
        remoteId: UUID = UUID(),
        userId: UUID,
        postId: UUID,
        createdAt: Date = Date(),
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        syncStatus: SyncStatus = .synced
    ) {
        self.remoteId = remoteId
        self.userId = userId
        self.postId = postId
        self.createdAt = createdAt
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
        self.syncStatusRaw = syncStatus.rawValue
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .synced }
        set { syncStatusRaw = newValue.rawValue }
    }
}
