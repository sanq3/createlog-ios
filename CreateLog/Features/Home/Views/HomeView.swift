import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat

    @State private var subHeaderVisible = true
    @State private var scrollInitialized = false
    @State private var lastScrollOffset: CGFloat = 0
    @State private var scrollProgress: CGFloat = 0
    @State private var viewWidth: CGFloat = 1
    @State private var showCompose = false
    private let titleRowHeight: CGFloat = 44
    private let tabBarSectionHeight: CGFloat = 38

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
                // Horizontal swipe → show sub header
                if abs(newOffset - oldOffset) > 5 {
                    subHeaderVisible = true
                }
            }

            // Fixed header
            VStack(spacing: 0) {
                // CreateLog title - always visible
                Text("CreateLog")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.clTextPrimary)
                    .frame(height: titleRowHeight)

                // Tab bar - hide on scroll down
                tabBar
                    .opacity(subHeaderVisible ? 1 : 0)
                    .frame(height: subHeaderVisible ? tabBarSectionHeight : 0)
            }
            .animation(.spring(duration: 0.3, bounce: 0.1), value: subHeaderVisible)

            // Bell icon overlaid top-right, hides with sub header
            HStack {
                Spacer()
                NavigationLink {
                    NotificationsView()
                } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color.clTextPrimary)
                        .frame(width: 44, height: 44)
                        .glassEffect(.regular, in: .circle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .frame(height: titleRowHeight)
            .opacity(subHeaderVisible ? 1 : 0)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: subHeaderVisible)

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
            .padding(.top, titleRowHeight + tabBarSectionHeight + 12)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { oldOffset, newOffset in
            // Skip initial scroll events to prevent hiding on launch
            guard scrollInitialized else {
                lastScrollOffset = newOffset
                scrollInitialized = true
                return
            }
            let delta = newOffset - lastScrollOffset
            let threshold: CGFloat = 15
            if delta > threshold {
                subHeaderVisible = false
            } else if delta < -threshold {
                subHeaderVisible = true
            }
            lastScrollOffset = newOffset
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
