import SwiftUI

struct HomeView: View {
    @Environment(\.dependencies) private var deps
    @State private var viewModel: FeedViewModel?
    @State private var segmentIndex = 0

    /// ViewModel から実データを返す。MockData fallback は排除 (2026-04-13 v2.0 接続)。
    private var posts: [Post] {
        viewModel?.posts ?? []
    }
    @Binding var tabBarOffset: CGFloat
    let reselectCount: Int

    // DEBUG
    @State private var showOnboarding = false

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

    // 各ページは現在 segment の posts をそのまま表示する。
    // horizontal swipe で segmentIndex が変わると ViewModel の segment が切り替わり posts が更新される。
    private var timelinePosts: [Post] { posts }
    private var followingPosts: [Post] { posts }

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
                        // DEBUG: onboarding
                        Button {
                            showOnboarding = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.clTextTertiary)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)

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
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .glassEffect(.regular.interactive(), in: .circle)
            .contentShape(Circle().inset(by: -8))
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, max(6, 56 - tabBarOffset))
        }
        .fullScreenCover(isPresented: $showCompose) {
            ComposeView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                isPresented: $showOnboarding,
                authViewModel: AuthViewModel(authService: deps.authService)
            )
        }
        .errorBanner(Binding(
            get: { viewModel?.errorMessage },
            set: { viewModel?.errorMessage = $0 }
        ))
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = FeedViewModel(
                    postRepository: deps.postRepository,
                    likeRepository: deps.likeRepository
                )
            }
            await viewModel?.loadFeed()
        }
        .onChange(of: segmentIndex) { _, _ in
            viewModel?.segment = segmentIndex == 0 ? .timeline : .following
            Task { await viewModel?.onSegmentChange() }
        }
        .onChange(of: reselectCount) {
            if isAtTop {
                // Already at top → refresh
                isRefreshing = true
                HapticManager.light()
                Task {
                    await viewModel?.refresh()
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
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
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
    }

    private func feedPage(for pagePosts: [Post]) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if isRefreshing || (viewModel?.isLoading == true && pagePosts.isEmpty) {
                    ProgressView()
                        .padding(.top, 8)
                }

                if pagePosts.isEmpty, viewModel?.isLoading == false {
                    emptyFeedState
                        .padding(.top, 80)
                }

                ForEach(Array(pagePosts.enumerated()), id: \.element.id) { index, post in
                    NavigationLink {
                        PostDetailView(post: post)
                    } label: {
                        PostCardView(post: post)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        // 末尾の数件に到達したら次ページを読み込む
                        if index >= pagePosts.count - 3 {
                            Task { await viewModel?.loadMore() }
                        }
                    }
                }

                if viewModel?.isLoadingMore == true {
                    ProgressView()
                        .padding(.vertical, 12)
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

    // MARK: - Empty state

    private var emptyFeedState: some View {
        VStack(spacing: 12) {
            Image(systemName: segmentIndex == 0 ? "tray" : "person.2")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.clTextTertiary)
            Text(segmentIndex == 0 ? "home.empty.timeline" : "home.empty.following")
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
            if segmentIndex == 1 {
                Text("post.empty.following")
                    .font(.clCaption)
                    .foregroundStyle(Color.clTextTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Tab Bar (hides on scroll down, shows on scroll up / horizontal swipe)

    private var tabBar: some View {
        HStack(spacing: 24) {
            tabLabel(title: "home.tab.timeline", index: 0)
            tabLabel(title: "home.tab.following", index: 1)
        }
        .padding(.vertical, 8)
        .frame(height: tabBarSectionHeight)
    }

    private func tabLabel(title: LocalizedStringKey, index: Int) -> some View {
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
