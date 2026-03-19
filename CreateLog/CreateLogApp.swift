import SwiftUI

@main
struct CreateLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var tabBarOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clBackground
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView(tabBarOffset: $tabBarOffset) }
                case 1: NavigationStack { DiscoverView(tabBarOffset: $tabBarOffset) }
                case 2: NavigationStack { RecordingTabView() }
                case 3: NavigationStack { NotificationsView() }
                case 4: NavigationStack { ProfileView() }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .offset(y: tabBarOffset)
        }
    }
}
