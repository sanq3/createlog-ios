import Foundation
import SwiftData
import OSLog

private let cleanupLogger = Logger(subsystem: "com.sanq3.createlog", category: "AuthCleanup")

/// logout / deleteAccount 成功時に呼ばれる後始末サービス。
///
/// ## 責務
/// - SwiftData cache の完全削除 (別ユーザー再ログイン時の情報漏洩防止)
/// - `DomainContext.reset()` で共有状態クリア
/// - `DomainEventBus.publish(.sessionCleared)` で全 VM に通知
///
/// ## なぜ AuthViewModel に直接書かないか
/// AuthViewModel は「認証 UI の state」を管轄する責務に閉じ込めたい。
/// cache 削除や event 通知は auth の関心ではないため、専用 service に切り出す。
/// これにより AuthViewModel の test 時に SwiftData/EventBus への依存を切れる。
///
/// ## 削除対象
/// **全 SD*Cache + SDOfflineOperation + 端末固有ドメインデータ (Project/TimeEntry/Category)**。
/// 理由: 別ユーザーで再ログインした際に前ユーザーのローカルデータが見えてしまう事を防ぐ。
/// offline で未 sync のデータは logout 時に失われるが、これは大手 SNS (X/Instagram) の
/// 業界標準挙動に従う (logout = local state wipe)。
@MainActor
final class AuthCleanupService {
    private let domainContext: DomainContext
    private let domainEventBus: DomainEventBus
    private let modelContainer: ModelContainer?

    init(
        domainContext: DomainContext,
        domainEventBus: DomainEventBus,
        modelContainer: ModelContainer?
    ) {
        self.domainContext = domainContext
        self.domainEventBus = domainEventBus
        self.modelContainer = modelContainer
    }

    /// logout / deleteAccount 成功直後に呼ぶ。同期完了後 event を publish するので、
    /// 呼出側は await 不要 (method 自体は非 async、全 operation main actor 上同期)。
    func performCleanup() {
        domainContext.reset()
        clearSwiftDataCache()
        domainEventBus.publish(.sessionCleared)
    }

    /// 認証成立時に observeAuthState から呼ばれ、共有 `DomainContext.currentUserId` を更新する。
    /// 全 VM が `@Environment`/`@Observable` 経由で最新ユーザー ID を参照できるようにする。
    /// nil 渡しは logout 経由で使わず、必ず `performCleanup()` 全 reset を通す。
    func setCurrentUserId(_ id: UUID?) {
        domainContext.currentUserId = id
    }

    /// 全 SwiftData schema から instance を一括削除 + save。
    /// `ModelContext.delete(model:)` は iOS 18+ の一括削除 API (iOS 26 で使用可)。
    ///
    /// 個別 delete は schema 未作成 / 空 collection に対しても no-op で安全なので `try?` で吸収。
    /// 最後の `save()` のみ catch してログ化 — 失敗すると次ユーザー再ログイン時に前ユーザー
    /// データが残る致命的 UX になるため、silent に握りつぶさず Logger.error で可視化する。
    private func clearSwiftDataCache() {
        guard let modelContainer else { return }
        let context = modelContainer.mainContext

        // SNS cache 7 種 (T7c Offline-first decorator の read cache)
        try? context.delete(model: SDPostCache.self)
        try? context.delete(model: SDLikeCache.self)
        try? context.delete(model: SDBookmarkCache.self)
        try? context.delete(model: SDFollowCache.self)
        try? context.delete(model: SDCommentCache.self)
        try? context.delete(model: SDNotificationCache.self)
        try? context.delete(model: SDProfileCache.self)

        // 記録タブ関連 (端末固有ドメインデータ)
        try? context.delete(model: SDLogCache.self)
        try? context.delete(model: SDTimeEntry.self)
        try? context.delete(model: SDProject.self)
        try? context.delete(model: SDCategory.self)

        // Offline queue (pending operation も別ユーザーで継続しない)
        try? context.delete(model: SDOfflineOperation.self)

        do {
            try context.save()
        } catch {
            cleanupLogger.error("SwiftData cache save after clear failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
