import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    @State private var scrollProgress: CGFloat = 0
    @State private var viewWidth: CGFloat = 1
    @State private var showCompose = false
    private let topRowHeight: CGFloat = 50
    private let tabBarSectionHeight: CGFloat = 46

    private var timelinePosts: [Post] { Array(posts.prefix(5)) }
    private var followingPosts: [Post] { Array(posts.suffix(from: min(5, posts.count))) }

    var body: some View {
        ZStack(alignment: .top) {
            // Feed: horizontal paging with real-time swipe
            ScrollView(.horizontal) {
                HStack(spacing: 0) {
                    feedPage(for: timelinePosts)
                        .containerRelativeFrame(.horizontal)
                        .id(0)
                    feedPage(for: followingPosts)
                        .containerRelativeFrame(.horizontal)
                        .id(1)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: Binding(
                get: { segmentIndex },
                set: { if let v = $0 { segmentIndex = v } }
            ))
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.x
            } action: { _, newOffset in
                scrollProgress = newOffset / max(1, viewWidth)
            }

            // Top row header (hides on scroll)
            topHeaderRow
                .offset(y: headerOffset)

            // Sticky tab bar (pins to top with blur)
            stickyTabBar
                .offset(y: max(0, topRowHeight + headerOffset))

            // Status bar mask
            Color.clear
                .frame(height: 0)
                .background(Color.clBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
        }
        .background(Color.clBackground)
        .overlay(alignment: .bottomTrailing) {
            Button {
                HapticManager.light()
                showCompose = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.clAccent, in: Circle())
                    .shadow(color: Color.clAccent.opacity(0.3), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 100)
            .offset(y: tabBarOffset)
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeView()
        }
        .navigationBarHidden(true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            if abs(viewWidth - newWidth) > 1 {
                viewWidth = newWidth
            }
        }
        // Edge swipe for side menu (UIGestureRecognizerRepresentable, priority over ScrollView)
        .gesture(
            EdgePanGesture(
                dragOffset: $sideMenuDragOffset,
                isEnabled: segmentIndex == 0,
                onEnd: { shouldOpen in
                    if shouldOpen {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            showSideMenu = true
                            sideMenuDragOffset = 0
                        }
                    } else {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            sideMenuDragOffset = 0
                        }
                    }
                }
            )
        )
    }

    private func feedPage(for pagePosts: [Post]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(pagePosts.enumerated()), id: \.element.id) { _, post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, topRowHeight + tabBarSectionHeight + 12)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollHide(headerHeight: topRowHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)
    }

    private var topRowOpacity: Double {
        topRowHeight > 0 ? 1.0 + Double(headerOffset / topRowHeight) : 1.0
    }

    // MARK: - Top Row (hides on scroll)

    private var topHeaderRow: some View {
        HStack {
            Spacer()

            Button {
                HapticManager.light()
            } label: {
                HStack(spacing: 6) {
                    HStack(spacing: -5) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(
                                    Color(hue: Double(i) * 0.3, saturation: 0.2, brightness: 0.5)
                                )
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(Color.clBackground, lineWidth: 1.5))
                        }
                    }

                    Text("3人が作業中")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.clTextSecondary)

                    Circle()
                        .fill(Color.clSuccess)
                        .frame(width: 5, height: 5)
                        .modifier(PulseModifier())
                }
            }
            .buttonStyle(.plain)

            Spacer()

            NavigationLink {
                NotificationsView()
            } label: {
                Image(systemName: "bell")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(width: 40, height: 40)
                    .background(Color.clTextSecondary.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(Color.clBackground)
        .opacity(topRowOpacity)
    }

    // MARK: - Sticky Tab Bar (always visible)

    private var stickyTabBar: some View {
        tabBar
            .padding(.bottom, 4)
    }

    // MARK: - Tab Bar with Sliding Indicator

    private var tabBar: some View {
        VStack(spacing: 0) {
            // Tab labels
            HStack(spacing: 0) {
                tabLabel(title: "タイムライン", index: 0)
                tabLabel(title: "フォロー中", index: 1)
            }

            // Sliding indicator (follows scroll position in real-time)
            GeometryReader { geo in
                let tabWidth = geo.size.width / 2
                let clampedProgress = max(0, min(1, scrollProgress))

                Capsule()
                    .fill(Color.clAccent)
                    .frame(width: 28, height: 3)
                    .position(
                        x: tabWidth / 2 + clampedProgress * tabWidth,
                        y: 1.5
                    )
            }
            .frame(height: 3)
        }
    }

    private func tabLabel(title: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                segmentIndex = index
            }
            HapticManager.light()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: segmentIndex == index ? .bold : .regular))
                .foregroundStyle(segmentIndex == index ? Color.clTextPrimary : Color.clTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
