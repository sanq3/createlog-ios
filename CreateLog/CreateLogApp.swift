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

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.clBackground
                .ignoresSafeArea()

            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView() }
                case 1: NavigationStack { DiscoverView() }
                case 2: NavigationStack { RecordingTabView() }
                case 3: NavigationStack { NotificationsView() }
                case 4: NavigationStack { ProfileView() }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 44)

            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}
