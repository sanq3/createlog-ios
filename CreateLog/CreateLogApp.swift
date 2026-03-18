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
        TabView(selection: $selectedTab) {
            Tab("ホーム", systemImage: "house.fill", value: 0) {
                NavigationStack {
                    HomeView()
                }
            }

            Tab("発見", systemImage: "magnifyingglass", value: 1) {
                NavigationStack {
                    DiscoverView()
                }
            }

            Tab("記録", systemImage: "circle.dotted.and.circle", value: 2) {
                NavigationStack {
                    RecordingTabView()
                }
            }

            Tab("通知", systemImage: "bell.fill", value: 3) {
                NavigationStack {
                    NotificationsView()
                }
            }

            Tab("マイ", systemImage: "person.fill", value: 4) {
                NavigationStack {
                    ProfileView()
                }
            }
        }
        .tint(Color.clAccent)
        .onChange(of: selectedTab) { _, _ in
            HapticManager.selection()
        }
    }
}
