import SwiftUI

struct MainTabView: View {
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
    }
}
