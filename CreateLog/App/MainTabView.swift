import SwiftUI

struct MainTabView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedTab = 0
    @State private var tabBarOffset: CGFloat = 0
    @State private var homeReselectCount = 0
    @State private var discoverReselectCount = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clBackground
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView(tabBarOffset: $tabBarOffset, reselectCount: homeReselectCount) }
                case 1: NavigationStack { DiscoverView(tabBarOffset: $tabBarOffset, reselectCount: discoverReselectCount) }
                case 2: NavigationStack { RecordingTabView(tabBarOffset: $tabBarOffset) }
                case 3: NavigationStack { ReportDashboardView() }
                case 4: NavigationStack { ProfileView() }
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
    }
}
