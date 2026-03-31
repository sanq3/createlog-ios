import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat
    let reselectCount: Int

    @State private var feedScrollPosition: ScrollPosition = .init(edge: .top)
    @State private var isRefreshing = false
    @State private var isAtTop = true
    @State private var isScrollingToTop = false
    @State private var headerVisible = true
    @State private var lastScrollY: CGFloat = 0
    @State private var accumulatedDistance: CGFloat = 0
    @State private var scrollingDown = false
    @State private var scrollProgress: CGFloat = 0
    @State private var viewWidth: CGFloat = 1
    @State private var showCompose = false
    private let titleRowHeight: CGFloat = 44
    private let tabBarSectionHeight: CGFloat = 38
    private let hideThreshold: CGFloat = 15
    private let showThreshold: CGFloat = 100

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
            } action: { oldOffset, newOffset in
                scrollProgress = newOffset / max(1, viewWidth)
                // Horizontal swipe → show header
                if abs(newOffset - oldOffset) > 5, !headerVisible {
                    withAnimation(.easeOut(duration: 0.3)) {
                        headerVisible = true
                        tabBarOffset = 0
                    }
                    accumulatedDistance = 0
                }
            }

            // Header - all fades on scroll
            VStack(spacing: 0) {
                ZStack {
                    Text("CreateLog")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.clTextPrimary)

                    HStack {
                        Spacer()
                        NavigationLink {
                            NotificationsView()
                        } label: {
                            Image(systemName: "bell")
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(Color.clTextPrimary)
                                .frame(width: 52, height: 40)
                                .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: titleRowHeight)

                tabBar
            }
            .opacity(headerVisible ? 1 : 0)

        }
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
            .padding(.bottom, 80)
            .offset(y: tabBarOffset)
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeView()
        }
        .navigationBarHidden(true)
        .onChange(of: reselectCount) {
            if isAtTop {
                // Already at top → refresh
                isRefreshing = true
                HapticManager.light()
                // Simulate refresh (replace with real API call later)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    isRefreshing = false
                }
            } else {
                // Scroll to top — disable scroll triggers during animation
                isScrollingToTop = true
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    feedScrollPosition.scrollTo(edge: .top)
                    headerVisible = true
                    tabBarOffset = 0
                }
                HapticManager.light()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isScrollingToTop = false
                    accumulatedDistance = 0
                }
            }
        }
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
                if isRefreshing {
                    ProgressView()
                        .padding(.top, 8)
                }

                ForEach(Array(pagePosts.enumerated()), id: \.element.id) { _, post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, titleRowHeight + tabBarSectionHeight)
            .padding(.bottom, 60)
        }
        .scrollPosition($feedScrollPosition)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { _, newValue in
            let delta = newValue - lastScrollY
            lastScrollY = newValue
            isAtTop = newValue <= 5

            // Skip during programmatic scroll-to-top
            guard !isScrollingToTop else { return }

            // At top: always show
            guard newValue > 0 else {
                if !headerVisible {
                    withAnimation(.easeOut(duration: 0.3)) {
                        headerVisible = true
                        tabBarOffset = 0
                    }
                }
                accumulatedDistance = 0
                return
            }

            guard abs(delta) > 0.5 else { return }

            let nowDown = delta > 0
            if nowDown != scrollingDown {
                // Direction changed → reset accumulator
                scrollingDown = nowDown
                accumulatedDistance = 0
            }
            accumulatedDistance += abs(delta)

            if scrollingDown, accumulatedDistance > hideThreshold, headerVisible {
                withAnimation(.easeOut(duration: 0.3)) {
                    headerVisible = false
                    tabBarOffset = 100
                }
            } else if !scrollingDown, accumulatedDistance > showThreshold, !headerVisible {
                withAnimation(.easeOut(duration: 0.3)) {
                    headerVisible = true
                    tabBarOffset = 0
                }
            }
        }
    }

    // MARK: - Tab Bar (hides on scroll down, shows on scroll up / horizontal swipe)

    private var tabBar: some View {
        HStack(spacing: 24) {
            tabLabel(title: "タイムライン", index: 0)
            tabLabel(title: "フォロー中", index: 1)
        }
        .padding(.vertical, 8)
        .frame(height: tabBarSectionHeight)
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
        }
        .buttonStyle(.plain)
    }
}
