import SwiftUI
import SwiftData
@preconcurrency import Supabase

/// Composition Root: 全依存の具象インスタンスを集約
///
/// 本番(リアル)とプレビュー(モック)の2系統を明示的に分離する。
/// `EnvironmentKey.defaultValue` では絶対にリアルクライアントを初期化しない (xcconfig未設定でfatalError回避)。
final class DependencyContainer: Sendable {
    let supabaseClient: SupabaseClient
    let authService: any AuthServiceProtocol
    let logRepository: any LogRepositoryProtocol
    let categoryRepository: any CategoryRepositoryProtocol
    let statsRepository: any StatsRepositoryProtocol
    let profileRepository: any ProfileRepositoryProtocol
    let appRepository: any AppRepositoryProtocol
    let postRepository: any PostRepositoryProtocol
    let followRepository: any FollowRepositoryProtocol
    let likeRepository: any LikeRepositoryProtocol
    let bookmarkRepository: any BookmarkRepositoryProtocol
    let commentRepository: any CommentRepositoryProtocol
    let notificationRepository: any NotificationRepositoryProtocol
    let searchRepository: any SearchRepositoryProtocol
    let ugcRepository: any UGCRepositoryProtocol
    let networkMonitor: any NetworkMonitorProtocol
    /// T7a-3: OfflineSync service。ModelContainer が無い preview 経路では NoOp。
    let syncService: any SyncServiceProtocol
    // T4 (2026-04-12): Repository 補完 4 新規
    let subscriptionRepository: any SubscriptionRepositoryProtocol
    let monthlyRevenueRepository: any MonthlyRevenueRepositoryProtocol
    let hashtagRepository: any HashtagRepositoryProtocol
    let autoTrackingRepository: any AutoTrackingRepositoryProtocol

    /// 本番用: xcconfigから読み込んだSupabaseClientを使用
    static func live() -> DependencyContainer {
        DependencyContainer(client: SupabaseClientFactory.shared)
    }

    init(
        client: SupabaseClient = SupabaseClientFactory.shared,
        modelContainer: ModelContainer? = nil
    ) {
        self.supabaseClient = client
        self.authService = SupabaseAuthService(client: client)
        let logRepo = SupabaseLogRepository(client: client)
        self.categoryRepository = SupabaseCategoryRepository(client: client)
        self.statsRepository = SupabaseStatsRepository(client: client)
        // 2026-04-16: Profile flicker 根本修正。SDProfileCache から同期 read する Decorator で wrap。
        // ModelContainer が無い preview 経路では underlying の SupabaseProfileRepository を直接使用 (cache 無効)。
        let supabaseProfileRepo = SupabaseProfileRepository(client: client)
        if modelContainer != nil {
            self.profileRepository = OfflineFirstProfileRepository(
                underlying: supabaseProfileRepo,
                modelContainer: modelContainer
            )
        } else {
            self.profileRepository = supabaseProfileRepo
        }
        self.appRepository = SupabaseAppRepository(client: client)
        self.searchRepository = SupabaseSearchRepository(client: client)
        self.ugcRepository = SupabaseUGCRepository(client: client)
        // T4 (2026-04-12): 4 新規 Repository
        self.subscriptionRepository = SupabaseSubscriptionRepository(client: client)
        self.monthlyRevenueRepository = SupabaseMonthlyRevenueRepository(client: client)
        self.hashtagRepository = SupabaseHashtagRepository(client: client)
        self.autoTrackingRepository = SupabaseAutoTrackingRepository(client: client)

        let monitor = NetworkMonitor()
        self.networkMonitor = monitor

        // SNS underlying Supabase repo (T7c Decorator の wrap 対象)
        let supabasePostRepo = SupabasePostRepository(client: client)
        let supabaseFollowRepo = SupabaseFollowRepository(client: client)
        let supabaseLikeRepo = SupabaseLikeRepository(client: client)
        let supabaseBookmarkRepo = SupabaseBookmarkRepository(client: client)
        let supabaseCommentRepo = SupabaseCommentRepository(client: client)
        let supabaseNotificationRepo = SupabaseNotificationRepository(client: client)

        // T7a-3 + T7c: Sync 基盤配線。ModelContainer 未注入 (preview / 未初期化) は NoOp 代替
        if let modelContainer {
            let queueActor = OfflineQueueActor(modelContainer: modelContainer)

            // Current user id provider (Supabase session から取得、失敗時 nil)
            let authClient = client
            let userIdProvider: @Sendable () async -> UUID? = {
                guard let session = try? await authClient.auth.session else { return nil }
                return session.user.id
            }

            // T7b: LogCacheWriter (SDLogCache schema を含む modelContainer 必須)
            let logCacheWriter = LogCacheWriter(modelContainer: modelContainer)

            // T7a/T7b: LogFlushExecutor (2-arg, cacheWriter 注入) + T7c: SNS Executors 5 種
            // Executors は underlying Supabase repo を参照 (Decorator は使わない、ループ回避)
            let logExecutor = LogFlushExecutor(
                logRepository: logRepo,
                cacheWriter: logCacheWriter
            )
            let postExecutor = PostFlushExecutor(postRepository: supabasePostRepo)
            let likeExecutor = LikeFlushExecutor(likeRepository: supabaseLikeRepo)
            let bookmarkExecutor = BookmarkFlushExecutor(bookmarkRepository: supabaseBookmarkRepo)
            let followExecutor = FollowFlushExecutor(followRepository: supabaseFollowRepo)
            let commentExecutor = CommentFlushExecutor(commentRepository: supabaseCommentRepo)
            let notificationExecutor = NotificationFlushExecutor(notificationRepository: supabaseNotificationRepo)

            let sync = OfflineSyncService(
                queue: queueActor,
                network: monitor,
                executors: [
                    logExecutor,
                    postExecutor,
                    likeExecutor,
                    bookmarkExecutor,
                    followExecutor,
                    commentExecutor,
                    notificationExecutor
                ]
            )
            self.syncService = sync

            // T7b: Log Decorator (OfflineFirstLogRepository)
            self.logRepository = OfflineFirstLogRepository(
                underlying: logRepo,
                cacheWriter: logCacheWriter,
                modelContainer: modelContainer,
                syncService: sync
            )

            // T7b: memo ハック migration (起動時 1 回限り、best-effort)
            let migrationService = MigrationService(modelContainer: modelContainer)
            Task { await migrationService.migrateLogMemoRemoteIds() }

            // T7c: SNS Decorator Repositories (SDPostCache / Like / Follow / Comment / Notification)
            // 2026-04-16: Post / Comment Decorator に profileRepository を注入。
            // feed / comment 取得時に post.author (handle/displayName/avatarUrl) を
            // SDProfileCache へ precache 書き込み (Bluesky pattern)。他人プロフィール遷移で spinner ゼロ。
            let profileRepoForPrecache = self.profileRepository
            self.postRepository = OfflineFirstPostRepository(
                underlying: supabasePostRepo,
                modelContainer: modelContainer,
                syncService: sync,
                profileRepository: profileRepoForPrecache
            )
            self.commentRepository = OfflineFirstCommentRepository(
                underlying: supabaseCommentRepo,
                modelContainer: modelContainer,
                syncService: sync,
                profileRepository: profileRepoForPrecache
            )
            self.likeRepository = OfflineFirstLikeRepository(
                underlying: supabaseLikeRepo,
                modelContainer: modelContainer,
                syncService: sync,
                currentUserIdProvider: userIdProvider
            )
            self.bookmarkRepository = OfflineFirstBookmarkRepository(
                underlying: supabaseBookmarkRepo,
                modelContainer: modelContainer,
                syncService: sync,
                currentUserIdProvider: userIdProvider
            )
            self.followRepository = OfflineFirstFollowRepository(
                underlying: supabaseFollowRepo,
                modelContainer: modelContainer,
                syncService: sync,
                currentUserIdProvider: userIdProvider
            )
            self.notificationRepository = OfflineFirstNotificationRepository(
                underlying: supabaseNotificationRepo,
                modelContainer: modelContainer,
                syncService: sync,
                currentUserIdProvider: userIdProvider
            )
        } else {
            // Preview / 未初期化: Decorator 無しで underlying Supabase 直接使用 + NoOp sync
            self.logRepository = logRepo
            self.postRepository = supabasePostRepo
            self.followRepository = supabaseFollowRepo
            self.likeRepository = supabaseLikeRepo
            self.bookmarkRepository = supabaseBookmarkRepo
            self.commentRepository = supabaseCommentRepo
            self.notificationRepository = supabaseNotificationRepo
            self.syncService = NoOpSyncService()
        }
    }
}

// MARK: - Environment

private struct DependencyContainerKey: EnvironmentKey {
    /// プレビュー/未注入時のフォールバック。
    /// 実際にアクセスされた時点で初めてリアルClientを生成する (SwiftUI Previewでは置換される想定)。
    static let defaultValue: DependencyContainer = DependencyContainer.live()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}
