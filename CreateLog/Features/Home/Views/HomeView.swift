import SwiftUI

struct HomeView: View {
    @State private var segmentIndex = 0
    @State private var posts = MockData.posts
    @Binding var tabBarOffset: CGFloat
    @Binding var showSideMenu: Bool
    @Binding var sideMenuDragOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    @State private var headerHeight: CGFloat = 92
    @State private var scrollProgress: CGFloat = 0
    @State private var viewWidth: CGFloat = 1
    @State private var showCompose = false

    private var followingHandles: Set<String> {
        Set(MockData.users.filter(\.isFollowing).map(\.handle))
    }

    private var timelinePosts: [Post] { posts }

    private var followingPosts: [Post] {
        let filtered = posts.filter { followingHandles.contains($0.handle) }
        return filtered.isEmpty ? Array(posts.prefix(3)) : filtered
    }

    var body: some View {
        ZStack(alignment: .top) {
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
                set: { if let value = $0 { segmentIndex = value } }
            ))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.x
            } action: { _, newOffset in
                scrollProgress = newOffset / max(1, viewWidth)
            }

            headerView
                .offset(y: headerOffset)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.height
                } action: { newHeight in
                    if abs(headerHeight - newHeight) > 0.5 {
                        headerHeight = newHeight
                    }
                }

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
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { newWidth in
            if abs(viewWidth - newWidth) > 1 {
                viewWidth = newWidth
            }
        }
        .gesture(
            EdgePanGesture(
                dragOffset: $sideMenuDragOffset,
                isEnabled: segmentIndex == 0,
                onEnd: { shouldOpen in
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        showSideMenu = shouldOpen
                        sideMenuDragOffset = 0
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
            .padding(.top, headerHeight + 12)
            .padding(.bottom, 60)
        }
        .scrollIndicators(.hidden)
        .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)
    }

    private var headerView: some View {
        VStack(spacing: 0) {
            ZStack {
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

                HStack(spacing: 6) {
                    HStack(spacing: -5) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color(hue: Double(index) * 0.3, saturation: 0.2, brightness: 0.5))
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
                .padding(.horizontal, 10)
                .allowsHitTesting(false)
            }
            .frame(height: 36)
            .padding(.horizontal, 20)

            tabBar
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.clBackground)
    }

    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                tabLabel(title: "タイムライン", index: 0)
                tabLabel(title: "フォロー中", index: 1)
            }
            .frame(maxWidth: .infinity)

            GeometryReader { geometry in
                let tabWidth = geometry.size.width / 2
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
        .frame(maxWidth: .infinity)
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
