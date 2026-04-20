import Foundation
import Observation

/// App 全体で共有する domain 横断 state holder。
///
/// ## 目的
/// 「今 login しているユーザー」「ブロック中 / フォロー中のユーザー一覧」等、
/// **複数 VM が同時に参照する頻度が高い state** を集約する。
/// 各 VM が独立に fetch + cache するより、ここを single source of truth にすることで
/// 画面間の不整合を防ぐ。
///
/// ## 設計方針
/// - `@Observable` で SwiftUI が自動 rebind。iOS 26 WWDC 2025 の標準 pattern。
/// - `@MainActor` で全操作を main actor に閉じ込める。data race 無し。
/// - DependencyContainer の property として singleton ライフサイクル。
///   Environment 経由で全 View tree から参照可能。
/// - mutation は AuthViewModel / ProfileRepository 等の「責任 owner」だけが行う。
///   他の VM は **read-only** として観察するのが原則。
///
/// ## 境界 (これに入れない state)
/// - 画面固有の UI state (loading flag / text field text など) → VM の @Observable に残す
/// - サーバー集計値 (followersCount / likesCount) → 都度 fetch を信じる
/// - 一覧データ (posts / notifications) → 各 VM が管理、event bus で同期
///
/// ## reset() の責務
/// logout / deleteAccount 成功時に `DependencyContainer.signOut()` から呼ばれる。
/// 呼び出し側は同時に SwiftData cache clear + `DomainEventBus.publish(.sessionCleared)` も行う。
@Observable
@MainActor
final class DomainContext {
    /// 現在のログインユーザー ID (auth session の user.id)。未ログイン時 nil。
    var currentUserId: UUID?

    /// 現在のログインユーザーのプロフィール。ProfileEdit 後は即反映。
    var currentProfile: User?

    /// ブロック中のユーザー ID 一覧。Feed / Discover / Notifications のクライアント側
    /// filter fallback に使う (DB RLS でも filter されるが、UI 即時反映のため二重化)。
    var blockedUserIDs: Set<UUID> = []

    /// フォロー中のユーザー ID 一覧。follow button の state 表示高速化用。
    var followedUserIDs: Set<UUID> = []

    /// `nonisolated` init: DependencyContainer (非 MainActor 初期化 context) から作れるようにする。
    /// 以降の property アクセスは全て MainActor に閉じ込められる。
    nonisolated init() {}

    /// logout / deleteAccount / session expired 時に呼ぶ。
    func reset() {
        currentUserId = nil
        currentProfile = nil
        blockedUserIDs.removeAll()
        followedUserIDs.removeAll()
    }
}
