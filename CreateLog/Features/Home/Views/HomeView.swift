import SwiftUI

private enum HomeHorizontalMode {
    case page
    case sideMenu
}

private enum HomeGestureAxis {
    case undecided
    case horizontal
    case vertical
}

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 92
    @State private var pageDragOffset: CGFloat = 0
    @State private var gestureAxis: HomeGestureAxis = .undecided
    @State private var horizontalMode: HomeHorizontalMode?
    @State private var showCompose = false

    private let sideMenuWidthRatio: CGFloat = 0.82
    private let horizontalIntentThreshold: CGFloat = 12
    private let swipeVelocityThreshold: CGFloat = 500

    private var followingHandles: Set<String> {
        Set(MockData.users.filter(\.isFollowing).map(\.handle))
    }

    private var timelinePosts: [Post] { posts }

    private var followingPosts: [Post] {
        let filtered = posts.filter { followingHandles.contains($0.handle) }
        return filtered.isEmpty ? Array(posts.prefix(3)) : filtered
    }

    var body: some View {
        GeometryReader { proxy in
            let pageWidth = max(proxy.size.width, 1)

            ZStack(alignment: .top) {
                // Feed: unified horizontal pan for paging / side menu handoff
                HStack(spacing: 0) {
                    feedPage(for: timelinePosts)
                        .frame(width: pageWidth)
                    feedPage(for: followingPosts)
                        .frame(width: pageWidth)
                }
                .frame(width: pageWidth * 2, alignment: .leading)
                .offset(x: -CGFloat(segmentIndex) * pageWidth + pageDragOffset)
                .clipped()

                // Header (fixed)
                headerView(pageWidth: pageWidth)
                    .offset(y: headerOffset)
                    .background(Color.clBackground.ignoresSafeArea(edges: .top))
                    .onGeometryChange(for: CGFloat.self) { geometry in
                        geometry.size.height
                    } action: { newHeight in
                        if abs(headerHeight - newHeight) > 0.5 {
                            headerHeight = newHeight
                        }
                    }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(horizontalPanGesture(pageWidth: pageWidth), including: .all)
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
            .padding(.top, headerHeight + 12)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)
    }

    // MARK: - Header

    private func headerView(pageWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    HapticManager.light()
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        showSideMenu = true
                        sideMenuDragOffset = 0
                    }
                } label: {
                    AvatarView(initials: MockData.currentUser.initials, size: 28, status: MockData.currentUser.status)
                }
                .buttonStyle(.plain)

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
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color.clTextSecondary)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)

            // X-style tab bar with sliding indicator
            tabBar(pageWidth: pageWidth)
                .padding(.top, 6)
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.clBackground)
    }

    // MARK: - Tab Bar with Sliding Indicator

    private func tabBar(pageWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Tab labels
            HStack(spacing: 0) {
                tabLabel(title: "タイムライン", index: 0)
                tabLabel(title: "フォロー中", index: 1)
            }

            // Sliding indicator (follows scroll position in real-time)
            GeometryReader { geo in
                let tabWidth = geo.size.width / 2
                let clampedProgress = max(0, min(1, pageProgress(pageWidth: pageWidth)))

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
                pageDragOffset = 0
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

    // MARK: - Horizontal Pan

    private func horizontalPanGesture(pageWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                guard !showSideMenu else { return }
                handleHorizontalPanChanged(value, pageWidth: pageWidth)
            }
            .onEnded { value in
                guard !showSideMenu else { return }
                handleHorizontalPanEnded(value, pageWidth: pageWidth)
            }
    }

    private func handleHorizontalPanChanged(_ value: DragGesture.Value, pageWidth: CGFloat) {
        if gestureAxis == .undecided {
            let translation = value.translation
            guard
                abs(translation.width) > horizontalIntentThreshold
                    || abs(translation.height) > horizontalIntentThreshold
            else {
                return
            }

            gestureAxis = abs(translation.width) > abs(translation.height) * 1.15 ? .horizontal : .vertical
        }

        guard gestureAxis == .horizontal else { return }

        if horizontalMode == nil {
            horizontalMode = resolveHorizontalMode(translationWidth: value.translation.width)
        }

        switch horizontalMode {
        case .page:
            pageDragOffset = clampedPageDragOffset(
                translationWidth: value.translation.width,
                pageWidth: pageWidth
            )
        case .sideMenu:
            let menuWidth = pageWidth * sideMenuWidthRatio
            sideMenuDragOffset = max(0, min(menuWidth, value.translation.width))
        case nil:
            break
        }
    }

    private func handleHorizontalPanEnded(_ value: DragGesture.Value, pageWidth: CGFloat) {
        defer {
            gestureAxis = .undecided
            horizontalMode = nil
        }

        guard gestureAxis == .horizontal, let horizontalMode else {
            pageDragOffset = 0
            sideMenuDragOffset = 0
            return
        }

        switch horizontalMode {
        case .page:
            settlePage(from: value, pageWidth: pageWidth)
        case .sideMenu:
            settleSideMenu(from: value, pageWidth: pageWidth)
        }
    }

    private func resolveHorizontalMode(translationWidth: CGFloat) -> HomeHorizontalMode? {
        guard translationWidth != 0 else { return nil }

        if translationWidth > 0 {
            return segmentIndex == 0 ? .sideMenu : .page
        }

        return .page
    }

    private func clampedPageDragOffset(translationWidth: CGFloat, pageWidth: CGFloat) -> CGFloat {
        switch segmentIndex {
        case 0:
            return max(-pageWidth, min(0, translationWidth))
        case 1:
            return min(pageWidth, max(0, translationWidth))
        default:
            return 0
        }
    }

    private func settlePage(from value: DragGesture.Value, pageWidth: CGFloat) {
        let translation = pageDragOffset
        let velocity = value.velocity.width
        var nextIndex = segmentIndex

        if segmentIndex == 0 {
            if translation < -(pageWidth * 0.5) || velocity < -swipeVelocityThreshold {
                nextIndex = 1
            }
        } else if translation > pageWidth * 0.5 || velocity > swipeVelocityThreshold {
            nextIndex = 0
        }

        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            segmentIndex = nextIndex
            pageDragOffset = 0
        }
    }

    private func settleSideMenu(from value: DragGesture.Value, pageWidth: CGFloat) {
        let menuWidth = pageWidth * sideMenuWidthRatio
        let shouldOpen = sideMenuDragOffset > menuWidth * 0.5 || value.velocity.width > swipeVelocityThreshold

        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            showSideMenu = shouldOpen
            sideMenuDragOffset = 0
        }
    }

    private func pageProgress(pageWidth: CGFloat) -> CGFloat {
        guard pageWidth > 0 else { return CGFloat(segmentIndex) }
        let contentOffset = CGFloat(segmentIndex) * pageWidth - pageDragOffset
        return contentOffset / pageWidth
    }
}
