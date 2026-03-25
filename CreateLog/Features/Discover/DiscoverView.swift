import SwiftUI

// MARK: - Discover View

struct DiscoverView: View {
    @State private var searchText = ""
    @Binding var tabBarOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    @State private var currentScrollOffset: CGFloat = 0
    private let headerHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                MasonryGrid(items: MockData.discoverItems)
                    .padding(.horizontal, 12)
                    .padding(.top, headerHeight + 8)
                    .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                let delta = newValue - oldValue
                currentScrollOffset = newValue
                guard newValue > 0 else {
                    headerOffset = 0
                    tabBarOffset = 0
                    return
                }
                headerOffset = min(0, max(-headerHeight, headerOffset - delta))
                tabBarOffset = min(90, max(0, tabBarOffset + delta))
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .idle && oldPhase != .idle {
                    withAnimation(.easeOut(duration: 0.25)) {
                        if currentScrollOffset <= 0 {
                            headerOffset = 0
                            tabBarOffset = 0
                        } else {
                            headerOffset = -headerHeight
                            tabBarOffset = 90
                        }
                    }
                }
            }

            searchHeader
                .offset(y: headerOffset)

            Color.clear
                .frame(height: 0)
                .background(Color.clBackground.ignoresSafeArea(edges: .top))
                .allowsHitTesting(false)
        }
        .background(Color.clBackground)
        .navigationBarHidden(true)
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)

            Text("ユーザー、タグ、プロジェクトを検索")
                .font(.clBody)
                .foregroundStyle(Color.clTextTertiary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clSurfaceLow)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color.clBackground)
    }
}

// MARK: - Masonry Grid

private struct MasonryGrid: View {
    let items: [DiscoverItem]

    var body: some View {
        let (left, right) = distributeItems(items)

        HStack(alignment: .top, spacing: 10) {
            // Left column
            LazyVStack(spacing: 10) {
                ForEach(left) { item in
                    DiscoverCard(item: item)
                }
            }

            // Right column
            LazyVStack(spacing: 10) {
                ForEach(right) { item in
                    DiscoverCard(item: item)
                }
            }
        }
    }

    private func distributeItems(_ items: [DiscoverItem]) -> ([DiscoverItem], [DiscoverItem]) {
        var left: [DiscoverItem] = []
        var right: [DiscoverItem] = []
        var leftHeight: CGFloat = 0
        var rightHeight: CGFloat = 0

        for item in items {
            let h = cardHeight(item)
            if leftHeight <= rightHeight {
                left.append(item)
                leftHeight += h + 10
            } else {
                right.append(item)
                rightHeight += h + 10
            }
        }
        return (left, right)
    }

    private func cardHeight(_ item: DiscoverItem) -> CGFloat {
        switch item.size {
        case .small: return 180
        case .tall: return 280
        case .wide: return 180
        }
    }
}

// MARK: - Card

private struct DiscoverCard: View {
    let item: DiscoverItem

    private var cardHeight: CGFloat {
        switch item.size {
        case .small: return 180
        case .tall: return 280
        case .wide: return 180
        }
    }

    var body: some View {
        Button {
            HapticManager.light()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Visual area
                ZStack(alignment: .topTrailing) {
                    // Background
                    item.color
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: item.iconName)
                                    .font(.system(size: item.size == .tall ? 32 : 24))
                                    .foregroundStyle(.white.opacity(0.15))
                            }
                        )

                    // Type badge
                    typeBadge
                        .padding(8)
                }
                .frame(height: cardHeight - 64)
                .clipped()

                // Info area
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.clTextPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        AvatarView(initials: item.authorInitials, size: 16)

                        Text(item.authorName)
                            .font(.system(size: 10))
                            .foregroundStyle(Color.clTextTertiary)
                            .lineLimit(1)

                        Spacer()

                        metricLabel
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.clSurfaceLow)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var typeBadge: some View {
        let (icon, label) = typeInfo
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
                .background(.ultraThinMaterial, in: Capsule())
        )
    }

    private var typeInfo: (String, String) {
        switch item.type {
        case .project: return ("hammer.fill", "プロジェクト")
        case .article: return ("doc.text.fill", "記事")
        case .video: return ("play.fill", "動画")
        case .codeSnippet: return ("chevron.left.forwardslash.chevron.right", "Code")
        }
    }

    @ViewBuilder
    private var metricLabel: some View {
        switch item.type {
        case .project:
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.clTextTertiary)
                Text(item.metric)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }
        case .article, .codeSnippet:
            HStack(spacing: 2) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.clTextTertiary)
                Text(item.metric)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }
        case .video:
            HStack(spacing: 2) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color.clTextTertiary)
                Text(item.metric)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.clTextTertiary)
            }
        }
    }
}
