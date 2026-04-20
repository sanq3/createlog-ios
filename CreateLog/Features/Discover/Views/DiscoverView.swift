import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @Environment(\.dependencies) private var deps
    /// 2026-04-20: MainTabView @State から inject される。tab 切替で identity 破壊されない。
    @Bindable var viewModel: DiscoverViewModel
    @Binding var tabBarOffset: CGFloat
    let reselectCount: Int

    @State private var scrollPosition: ScrollPosition = .init(edge: .top)
    @State private var isRefreshing = false
    @State private var isAtTop = true
    @State private var headerOffset: CGFloat = 0
    private let headerHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                if isRefreshing {
                    ProgressView()
                        .padding(.top, headerHeight + 16)
                }

                if viewModel.isShowingResults {
                    searchResultsSection(viewModel: viewModel)
                        .padding(.top, headerHeight + 8)
                        .padding(.bottom, 100)
                } else {
                    feedSection(viewModel: viewModel)
                        .padding(.horizontal, 12)
                        .padding(.top, headerHeight + 8)
                        .padding(.bottom, 100)
                }
            }
            .scrollPosition($scrollPosition)
            .scrollIndicators(.hidden)
            .scrollHide(headerHeight: headerHeight, headerOffset: $headerOffset, tabBarOffset: $tabBarOffset)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { _, newValue in
                isAtTop = newValue <= 5
            }
            .refreshable {
                await viewModel.refreshFeed()
            }

            searchHeader
                .offset(y: headerOffset)
        }
        .background(Color.clBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // viewModel は MainTabView @State から inject。tab 初回可視時のみロード。
            if viewModel.feedItems.isEmpty {
                await viewModel.loadFeed()
            }
        }
        .onChange(of: reselectCount) {
            if isAtTop {
                isRefreshing = true
                HapticManager.light()
                Task {
                    await viewModel.refreshFeed()
                    isRefreshing = false
                }
            } else {
                withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                    scrollPosition.scrollTo(edge: .top)
                    headerOffset = 0
                    tabBarOffset = 0
                }
                HapticManager.light()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func feedSection(viewModel: DiscoverViewModel) -> some View {
        if viewModel.feedItems.isEmpty {
            if viewModel.isLoadingFeed {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                emptyState
                    .padding(.top, 80)
            }
        } else {
            VStack(spacing: 12) {
                DiscoverFeedGrid(items: viewModel.feedItems) {
                    Task { await viewModel.loadMoreFeed() }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .padding(.vertical, 16)
                }
            }
        }
    }

    @ViewBuilder
    private func searchResultsSection(viewModel: DiscoverViewModel) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if viewModel.isSearching {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else if let results = viewModel.searchResults {
                if results.users.isEmpty && results.posts.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    if !results.users.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("profile.users")
                                .font(.clHeadline)
                                .padding(.horizontal, 20)
                            ForEach(results.users, id: \.id) { profile in
                                suggestedUserRow(profile)
                            }
                        }
                    }
                    if !results.posts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("post.title")
                                .font(.clHeadline)
                                .padding(.horizontal, 20)
                            ForEach(results.posts, id: \.id) { postDto in
                                PostCardView(post: Post(from: postDto))
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
    }

    private func suggestedUserRow(_ profile: ProfileDTO) -> some View {
        NavigationLink {
            UserProfileView(user: User(from: profile))
        } label: {
            HStack(spacing: 12) {
                AvatarView(
                    initials: String((profile.displayName ?? profile.handle ?? "?").prefix(2)),
                    size: 44,
                    status: .offline,
                    imageURL: profile.avatarUrl.flatMap(URL.init(string:))
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.displayName ?? "")
                        .font(.clBody)
                        .foregroundStyle(Color.clTextPrimary)
                    if let handle = profile.handle {
                        Text("@\(handle)")
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.clTextTertiary)
            Text("discover.empty")
                .font(.clBody)
                .foregroundStyle(Color.clTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var headerContentOpacity: Double {
        headerHeight > 0 ? 1.0 + Double(headerOffset / headerHeight) : 1.0
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)

            TextField(
                "profile.search.placeholder",
                text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.searchQuery = $0 }
                )
            )
            .font(.clBody)
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .onSubmit {
                Task { await viewModel.search() }
            }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                    viewModel.searchResults = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.clTextTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 12))
        .opacity(headerContentOpacity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
}
