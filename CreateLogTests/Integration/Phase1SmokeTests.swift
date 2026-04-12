import Testing
import Foundation
import SwiftData
@testable import CreateLog

/// Phase 1 完了 gate 用の統合 smoke test (T8、2026-04-12)。
///
/// ## 目的
/// Phase 1 の T1-T7 完了後、個別 unit test では捕捉できない
/// 「横断的 regression」を検出するための薄い smoke test 集。
///
/// ## スコープ
/// - xcconfig 経由の Supabase 設定注入 (T2 test suite とは別観点)
/// - DependencyContainer.live() がエラーなく立ち上がる
/// - ModelContainer + Schema 5 SNS cache 追加後の migration 通過
/// - Sync 基盤 (OfflineSyncService + executors) が nil でない
/// - 5 SNS Decorator が各 protocol に conform している (compile-time check)
///
/// ## スコープ外
/// - 実ネットワーク疎通 (CI fragile 回避、T2 suite と同様)
/// - end-to-end user flow (UI test は別 target で T8 後半に追加)
/// - T7b 完了後の Log 同期整合性 (T7b 専用 test で cover)
///
/// ## 実行タイミング
/// CI と local で通る低速 integration test。
/// T8 完了後 `xcodebuild test` で全緑を Phase 1 完了 gate とする。
@Suite("Phase 1 Integration Smoke")
struct Phase1SmokeTests {

    // MARK: - ModelContainer

    /// T7a + T7c: Schema 5 + 5 = 10 @Model が正しく ModelContainer に乗るか。
    /// lightweight migration 要件違反で起動失敗するとここで落ちる。
    @Test("ModelContainer が 10 entity schema で起動できる")
    func testModelContainerSchemaCompiles() throws {
        let schema = Schema([
            SDCategory.self,
            SDProject.self,
            SDTimeEntry.self,
            SDOfflineOperation.self,
            SDLogCache.self,
            SDPostCache.self,
            SDLikeCache.self,
            SDFollowCache.self,
            SDCommentCache.self,
            SDNotificationCache.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        #expect(container.schema.entities.count == 10)
    }

    // MARK: - DependencyContainer

    /// T7a + T7c: DependencyContainer.init(modelContainer:) が Decorator 経路を含めて
    /// エラーなく完了するか。preview 経路 (modelContainer=nil) と本番経路 (inject) の両方。
    @Test("DependencyContainer が preview 経路で crash しない")
    func testDependencyContainerPreviewPath() {
        let deps = DependencyContainer()
        // syncService は NoOp、SNS repo は underlying 直接
        #expect(deps.syncService is NoOpSyncService)
    }

    @Test("DependencyContainer が modelContainer 注入経路で crash しない")
    func testDependencyContainerLivePath() throws {
        let schema = Schema([
            SDCategory.self,
            SDProject.self,
            SDTimeEntry.self,
            SDOfflineOperation.self,
            SDLogCache.self,
            SDPostCache.self,
            SDLikeCache.self,
            SDFollowCache.self,
            SDCommentCache.self,
            SDNotificationCache.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let deps = DependencyContainer(modelContainer: container)
        // syncService は OfflineSyncService (not NoOp)
        #expect(!(deps.syncService is NoOpSyncService))
        // Decorator が repo property に注入されている (compile-time: protocol conform)
        _ = deps.postRepository
        _ = deps.likeRepository
        _ = deps.followRepository
        _ = deps.commentRepository
        _ = deps.notificationRepository
    }

    // MARK: - Schema × Decorator 透過性

    /// T7c: Decorator Repository が preview 経路で underlying 直接使用に fallback するか。
    /// ModelContainer 未注入時に cache を使わず underlying に素通しする契約を verify。
    @Test("Preview 経路で SNS Decorator は underlying 直接使用に fallback")
    func testDecoratorPreviewFallback() {
        let deps = DependencyContainer()
        // modelContainer=nil なので postRepository は SupabasePostRepository 直接
        // (OfflineFirstPostRepository ではない)
        let postRepo = deps.postRepository
        #expect(!(postRepo is OfflineFirstPostRepository))
    }
}
