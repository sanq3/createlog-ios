import Foundation

/// アプリ全体で発生する domain 横断イベント。
///
/// ## 目的
/// 複数 ViewModel 間で state を同期するための event bus 通信型。
/// Repository 層が write 成功時に `DomainEventBus.publish(_:)` で発火し、
/// 各 VM が `.task { for await event in bus.events() { ... } }` で購読する。
///
/// ## 設計方針
/// - 全 case が `Sendable` 準拠の domain model (Post/Comment/UUID/プリミティブ) のみを搬送。
/// - Server truth から逸脱しないよう、楽観更新に必要な最小情報のみ。
/// - 追加時は「どの VM がどう反応すべきか」まで同時に考える。
enum DomainEvent: Sendable {
    // MARK: - Profile
    /// 自分のプロフィール更新。全 VM が posts/notifications の author 情報を patch。
    case profileUpdated(userId: UUID, displayName: String, handle: String, avatarUrl: String?, bio: String)

    // MARK: - Post
    /// 新規投稿完了。Feed VM が posts.insert(0, _) で即反映。
    case postCreated(Post)
    /// 投稿削除。Feed/Profile/Discover VM が posts から除去。
    case postDeleted(postId: UUID)
    /// 投稿編集。Feed/PostDetail VM が in-place 置換。
    case postEdited(Post)

    // MARK: - Like
    /// いいね toggled。Feed / PostDetail 両方の VM が in-place 更新。
    /// count は server 側 count を信じるのでなく、client 側増減後の値を broadcast。
    case likeToggled(postId: UUID, liked: Bool, count: Int)

    // MARK: - Follow
    /// フォロー toggled。UserProfile/FollowList/Discover VM が follow state + counts 更新。
    case followToggled(targetUserId: UUID, followed: Bool)

    // MARK: - Comment
    /// コメント追加。PostDetail VM が in-place append、Feed VM が post.comments +1。
    case commentAdded(postId: UUID, comment: Comment)
    /// コメント削除。PostDetail VM が除去、Feed VM が post.comments -1。
    case commentDeleted(postId: UUID, commentId: UUID)

    // MARK: - Notification
    case notificationRead(notificationId: UUID)
    case allNotificationsRead

    // MARK: - Block
    /// ブロック toggled。Feed/Discover/Notifications VM が該当ユーザーの content を filter 除去。
    case blockToggled(targetUserId: UUID, blocked: Bool)

    // MARK: - Auth
    /// ログアウト / アカウント削除完了。全 VM が state reset、Feed/Profile/Notifications をクリア。
    case sessionCleared
}
