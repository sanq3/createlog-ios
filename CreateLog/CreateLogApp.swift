import SwiftUI

@main
struct CreateLogApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView()
            }
            .tabItem {
                Label("ホーム", systemImage: selectedTab == 0 ? "house.fill" : "house")
            }
            .tag(0)

            NavigationStack {
                DiscoverView()
            }
            .tabItem {
                Label("発見", systemImage: "magnifyingglass")
            }
            .tag(1)

            NavigationStack {
                RecordingTabView()
            }
            .tabItem {
                Label("記録", systemImage: selectedTab == 2 ? "record.circle.fill" : "record.circle")
            }
            .tag(2)

            NavigationStack {
                NotificationsView()
            }
            .tabItem {
                Label("通知", systemImage: selectedTab == 3 ? "bell.fill" : "bell")
            }
            .tag(3)

            NavigationStack {
                ProfileView()
            }
            .tabItem {
                Label("マイ", systemImage: selectedTab == 4 ? "person.fill" : "person")
            }
            .tag(4)
        }
        .tint(Color.clAccent)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}
