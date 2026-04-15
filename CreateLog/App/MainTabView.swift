import SwiftUI

struct MainTabView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DeepLinkHandler.self) private var deepLinkHandler
    @State private var selectedTab = 0
    @State private var tabBarOffset: CGFloat = 0
    @State private var homeReselectCount = 0
    @State private var discoverReselectCount = 0
    @State private var deepLinkedUser: User?
    @State private var showDeepLinkedUser = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clBackground
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0:
                    tabNavigationStack {
                        HomeView(tabBarOffset: $tabBarOffset, reselectCount: homeReselectCount)
                    }
                case 1:
                    tabNavigationStack {
                        DiscoverView(tabBarOffset: $tabBarOffset, reselectCount: discoverReselectCount)
                    }
                case 2:
                    tabNavigationStack {
                        RecordingTabView(tabBarOffset: $tabBarOffset)
                    }
                case 3:
                    tabNavigationStack {
                        ReportDashboardView()
                    }
                case 4:
                    tabNavigationStack {
                        ProfileView(dependencies: dependencies)
                    }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab) { tabId in
                switch tabId {
                case 0: homeReselectCount += 1
                case 1: discoverReselectCount += 1
                default: break
                }
            }
            .offset(y: tabBarOffset)
        }
        .offlineBadge(networkMonitor: dependencies.networkMonitor)
        .task {
            // T7a-2: NetworkMonitor 起動 (アプリ生存中に 1 回だけ)。
            // 既存 CreateLogApp の `.task { authViewModel.observeAuthState() }` とは
            // 別 task として起動し、両者の AsyncStream が独立に動くようにする。
            await dependencies.networkMonitor.start()
        }
        .task {
            // T7a-3: OfflineSyncService drain loop 起動 (idempotent、.active 復帰時も OK)。
            // 内部で networkMonitor.start() を再呼び出しするが冪等 guard 済。
            await dependencies.syncService.start()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // T7a-3: scenePhase 遷移で drain loop を止める (background) / 再開 (active)。
            // inactive は短時間の中間状態 (電話 / notification center pull-down) のため無視。
            Task {
                switch newPhase {
                case .active:
                    await dependencies.syncService.start()  // idempotent
                case .background:
                    await dependencies.syncService.stop()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
        .onChange(of: deepLinkHandler.pendingLink) { _, link in
            Task { await consumeDeepLink(link) }
        }
        .task {
            await consumeDeepLink(deepLinkHandler.pendingLink)
        }
    }

    @ViewBuilder
    private func tabNavigationStack<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationDestination(isPresented: $showDeepLinkedUser) {
                    if let user = deepLinkedUser {
                        UserProfileView(user: user)
                    } else {
                        EmptyView()
                    }
                }
        }
    }

    /// DeepLink を consume して該当タブ/画面に遷移する。
    /// post は一旦 Home タブに飛ばすだけ (v2.1 で PostDetailView 直接遷移)。
    private func consumeDeepLink(_ link: DeepLink?) async {
        guard let link = deepLinkHandler.consume() ?? link else { return }

        switch link {
        case .post:
            selectedTab = 0
            // v2.1: PostDetailView 直接遷移 (Home の navigation path 経由)
        case .profile(let handle):
            // handle から profile を fetch して UserProfileView に遷移
            do {
                // SearchRepository 経由で handle 検索 (現状ベストな public API)
                let results = try await dependencies.searchRepository.search(query: handle, limit: 5)
                if let match = results.users.first(where: { $0.handle == handle }) {
                    deepLinkedUser = User(from: match)
                    showDeepLinkedUser = true
                }
            } catch {
                // 失敗時はサイレント
            }
        case .notifications:
            selectedTab = 0
            // v2.1: Home タブの NotificationsView に直接遷移 (現状は bell ボタンから)
        case .record:
            selectedTab = 2
        }
    }
}
