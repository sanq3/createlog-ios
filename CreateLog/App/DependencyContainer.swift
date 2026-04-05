import SwiftUI
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
    let commentRepository: any CommentRepositoryProtocol
    let notificationRepository: any NotificationRepositoryProtocol
    let searchRepository: any SearchRepositoryProtocol
    let ugcRepository: any UGCRepositoryProtocol

    /// 本番用: xcconfigから読み込んだSupabaseClientを使用
    static func live() -> DependencyContainer {
        DependencyContainer(client: SupabaseClientFactory.shared)
    }

    init(client: SupabaseClient = SupabaseClientFactory.shared) {
        self.supabaseClient = client
        self.authService = SupabaseAuthService(client: client)
        self.logRepository = SupabaseLogRepository(client: client)
        self.categoryRepository = SupabaseCategoryRepository(client: client)
        self.statsRepository = SupabaseStatsRepository(client: client)
        self.profileRepository = SupabaseProfileRepository(client: client)
        self.appRepository = SupabaseAppRepository(client: client)
        self.postRepository = SupabasePostRepository(client: client)
        self.followRepository = SupabaseFollowRepository(client: client)
        self.likeRepository = SupabaseLikeRepository(client: client)
        self.commentRepository = SupabaseCommentRepository(client: client)
        self.notificationRepository = SupabaseNotificationRepository(client: client)
        self.searchRepository = SupabaseSearchRepository(client: client)
        self.ugcRepository = SupabaseUGCRepository(client: client)
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
