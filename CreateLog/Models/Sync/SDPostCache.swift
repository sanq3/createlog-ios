import Foundation
import SwiftData

/// Remote `posts` テーブルの local cache。Offline-first 同期の読み出し側 cache。
///
/// ## 役割分担
/// - `SDOfflineOperation`: local mutation を queue 化する書き込み側
/// - `SDPostCache` (このファイル): remote posts を local 保持する読み出し側
///
/// ## lightweight migration 要件
/// 全非 optional フィールドに default 値を持たせる (SwiftData lightweight migration 要件)。
///
/// ## T7c scope
/// - Home feed / following feed の SWR (Stale-While-Revalidate) 読み取り元
/// - `OfflineFirstPostRepository` が `@Query` filter: `isDeleted == false` で feed 供給
/// - like/comment 数は realtime update (自投稿の post は posts table subscribe)
@Model
final class SDPostCache {
    // MARK: - Primary identity

    /// Remote `posts.id` (UUID PK)。
    var remoteId: UUID = UUID()

    /// 投稿者 `profiles.id`。RLS filter 用。
    var userId: UUID = UUID()

    // MARK: - Core fields

    var content: String = ""
    /// JSON encode した `[PostMediaItem]` (Phase 1/2/3 対応構造)。
    /// 2026-04-16: `[String]` → `[PostMediaItem]` に型変更 (posts.media_urls の jsonb 化と整合)。
    /// SwiftData lightweight migration 耐性のため `Data` で保持 (型自体は変えない)。
    var mediaUrlsData: Data = Data()
    var visibility: String = "public"
    var likesCount: Int = 0
    var commentsCount: Int = 0
    var repostsCount: Int = 0
    /// 投稿日時 (remote `created_at`)。feed sort key。
    var createdAt: Date = Date()

    // MARK: - Author denormalized (JOIN profile で都度 fetch を避ける)

    var authorDisplayName: String? = nil
    var authorHandle: String? = nil
    var authorAvatarUrl: String? = nil

    // MARK: - Cache metadata

    /// local cache の最終更新時刻 (SWR 判定用)。
    var syncedAt: Date = Date()

    /// Tombstone フラグ。remote 削除を local cache に反映する際に true にする。
    var isDeleted: Bool = false

    /// Remote 側の `updated_at` timestamp。LWW conflict resolution に使う。
    var updatedAtRemote: Date = Date()

    init(
        remoteId: UUID,
        userId: UUID,
        content: String,
        media: [PostMediaItem] = [],
        visibility: String = "public",
        likesCount: Int = 0,
        commentsCount: Int = 0,
        repostsCount: Int = 0,
        createdAt: Date,
        authorDisplayName: String? = nil,
        authorHandle: String? = nil,
        authorAvatarUrl: String? = nil,
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        updatedAtRemote: Date = Date()
    ) {
        self.remoteId = remoteId
        self.userId = userId
        self.content = content
        self.mediaUrlsData = (try? JSONEncoder().encode(media)) ?? Data()
        self.visibility = visibility
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.repostsCount = repostsCount
        self.createdAt = createdAt
        self.authorDisplayName = authorDisplayName
        self.authorHandle = authorHandle
        self.authorAvatarUrl = authorAvatarUrl
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
        self.updatedAtRemote = updatedAtRemote
    }

    /// `mediaUrlsData` を `[PostMediaItem]` として復元する computed property。
    /// 保存時は `setMedia(_:)` を使って整合性を保つ。
    var media: [PostMediaItem] {
        (try? JSONDecoder().decode([PostMediaItem].self, from: mediaUrlsData)) ?? []
    }

    func setMedia(_ items: [PostMediaItem]) {
        self.mediaUrlsData = (try? JSONEncoder().encode(items)) ?? Data()
    }
}
