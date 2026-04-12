import Foundation
import SwiftData

/// Remote `follows` テーブルの local cache。Offline-first 同期の読み出し側 cache。
///
/// ## T7c 位置付け
/// - follow/unfollow のオフライン操作を楽観的に反映
/// - `OfflineFirstFollowRepository.follow(userId:)` が SDFollowCache 即時 insert と
///   `OfflineQueueActor.enqueue` 併用
/// - `isFollowing(userId:)` は SDFollowCache.count(where: isDeleted == false) で local 判定
///
/// ## 命名
/// - `followerId`: フォロー「する」人 (= 自分)
/// - `followeeId`: フォロー「される」人
@Model
final class SDFollowCache {
    // MARK: - Primary identity

    /// Remote `follows.id`。local 暫定 UUID → remote 確定 UUID で置換。
    var remoteId: UUID = UUID()

    /// フォローする人 `profiles.id` (= 現在の user)。
    var followerId: UUID = UUID()

    /// フォローされる人 `profiles.id`。
    var followeeId: UUID = UUID()

    var createdAt: Date = Date()

    // MARK: - Cache metadata

    var syncedAt: Date = Date()
    var isDeleted: Bool = false
    var syncStatusRaw: String = SyncStatus.synced.rawValue

    init(
        remoteId: UUID = UUID(),
        followerId: UUID,
        followeeId: UUID,
        createdAt: Date = Date(),
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        syncStatus: SyncStatus = .synced
    ) {
        self.remoteId = remoteId
        self.followerId = followerId
        self.followeeId = followeeId
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
