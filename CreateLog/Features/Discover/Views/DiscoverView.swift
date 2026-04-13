import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @Environment(\.dependencies) private var deps
    @State private var viewModel: DiscoverViewModel?
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

                if let viewModel {
                    if viewModel.isShowingResults {
                        searchResultsSection(viewModel: viewModel)
                            .padding(.top, headerHeight + 8)
                            .padding(.bottom, 100)
                    } else if !viewModel.trendingTags.isEmpty || !viewModel.suggestedUsers.isEmpty {
                        exploreSection(viewModel: viewModel)
                            .padding(.top, headerHeight + 8)
                            .padding(.bottom, 100)
                    } else {
                        emptyState
                            .padding(.top, headerHeight + 80)
                    }
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

            searchHeader
                .offset(y: headerOffset)

        }
        .background(Color.clBackground)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = DiscoverViewModel(searchRepository: deps.searchRepository)
            }
            await viewModel?.loadInitialData()
        }
        .onChange(of: reselectCount) {
            if isAtTop {
                isRefreshing = true
                HapticManager.light()
                Task {
                    await viewModel?.loadInitialData()
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
    private func exploreSection(viewModel: DiscoverViewModel) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if !viewModel.trendingTags.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("トレンドタグ")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextPrimary)
                        .padding(.horizontal, 20)
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.trendingTags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.clBody)
                                .foregroundStyle(Color.clAccent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.clAccent.opacity(0.12), in: .capsule)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            if !viewModel.suggestedUsers.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("おすすめユーザー")
                        .font(.clHeadline)
                        .foregroundStyle(Color.clTextPrimary)
                        .padding(.horizontal, 20)
                    ForEach(viewModel.suggestedUsers, id: \.id) { profile in
                        suggestedUserRow(profile)
                    }
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
                            Text("ユーザー")
                                .font(.clHeadline)
                                .padding(.horizontal, 20)
                            ForEach(results.users, id: \.id) { profile in
                                suggestedUserRow(profile)
                            }
                        }
                    }
                    if !results.posts.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("投稿")
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
            Text("探索するものがまだありません")
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
                "ユーザー、タグ、プロジェクトを検索",
                text: Binding(
                    get: { viewModel?.searchQuery ?? "" },
                    set: { viewModel?.searchQuery = $0 }
                )
            )
            .font(.clBody)
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            .onSubmit {
                Task { await viewModel?.search() }
            }

            if let query = viewModel?.searchQuery, !query.isEmpty {
                Button {
                    viewModel?.searchQuery = ""
                    viewModel?.searchResults = nil
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
