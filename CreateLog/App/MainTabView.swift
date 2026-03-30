import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var tabBarOffset: CGFloat = 0
    @State private var showSideMenu = false
    @State private var sideMenuDragOffset: CGFloat = 0
    @State private var showSettings = false

    var body: some View {
        GeometryReader { geometry in
            let menuWidth = geometry.size.width * 0.82
            let prog = menuProgress(menuWidth: menuWidth)

            ZStack(alignment: .leading) {
                Color.clBackground
                    .ignoresSafeArea()

                // Side menu (behind main content)
                SideMenuView(isShowing: $showSideMenu) { destination in
                    handleNavigation(destination)
                }
                .frame(width: menuWidth)
                .offset(x: -menuWidth * 0.25 * (1 - prog))
                .gesture(closeDrag(menuWidth: menuWidth))

                // Main content (slides right with menu)
                mainContent
                    .offset(x: prog * menuWidth)
                    .shadow(
                        color: .black.opacity(0.12 * prog),
                        radius: 12, x: -4, y: 0
                    )
                    .overlay {
                        if showSideMenu {
                            Color.black
                                .opacity(Double(prog) * 0.35)
                                .onTapGesture { closeSideMenu() }
                                .gesture(closeDrag(menuWidth: menuWidth))
                        }
                    }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case 0: NavigationStack { HomeView(tabBarOffset: $tabBarOffset, showSideMenu: $showSideMenu, sideMenuDragOffset: $sideMenuDragOffset) }
                case 1: NavigationStack { DiscoverView(tabBarOffset: $tabBarOffset) }
                case 2: NavigationStack { RecordingTabView(tabBarOffset: $tabBarOffset) }
                case 3: NavigationStack { ReportDashboardView() }
                case 4: NavigationStack { ProfileView() }
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            CustomTabBar(selectedTab: $selectedTab)
                .offset(y: tabBarOffset)
        }
    }

    // MARK: - Progress

    private func menuProgress(menuWidth: CGFloat) -> CGFloat {
        guard menuWidth > 0 else { return 0 }
        let base: CGFloat = showSideMenu ? menuWidth : 0
        let current = max(0, min(menuWidth, base + sideMenuDragOffset))
        return current / menuWidth
    }

    // MARK: - Gestures

    /// Left swipe to close (on scrim or menu surface)
    private func closeDrag(menuWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                guard showSideMenu else { return }
                if value.translation.width < 0 {
                    sideMenuDragOffset = max(value.translation.width, -menuWidth)
                }
            }
            .onEnded { value in
                guard showSideMenu else { return }
                let remaining = menuWidth + sideMenuDragOffset
                if remaining < menuWidth * 0.6 || value.velocity.width < -500 {
                    closeSideMenu()
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        sideMenuDragOffset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func openSideMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            showSideMenu = true
            sideMenuDragOffset = 0
        }
    }

    private func closeSideMenu() {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            showSideMenu = false
            sideMenuDragOffset = 0
        }
    }

    private func handleNavigation(_ destination: SideMenuDestination) {
        closeSideMenu()
        switch destination {
        case .profile:
            selectedTab = 4
        case .settings:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                showSettings = true
            }
        default:
            break
        }
    }
}
