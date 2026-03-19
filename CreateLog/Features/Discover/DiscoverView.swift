import SwiftUI

// MARK: - Content Types

enum DiscoverContentType {
    case app
    case article
    case video
    case codeSnippet
}

enum DiscoverCardSize {
    case small  // 1x1
    case tall   // 1x2 (tall)
    case wide   // takes full width occasionally
}

struct DiscoverItem: Identifiable {
    let id = UUID()
    let type: DiscoverContentType
    let size: DiscoverCardSize
    let title: String
    let subtitle: String
    let authorName: String
    let authorInitials: String
    let color: Color // placeholder for image
    let iconName: String
    let metric: String
}

// MARK: - Mock Data

private let discoverItems: [DiscoverItem] = [
    DiscoverItem(
        type: .app, size: .tall,
        title: "Tempo",
        subtitle: "習慣トラッカー",
        authorName: "田中ゆうき", authorInitials: "田",
        color: Color(red: 0.2, green: 0.25, blue: 0.45),
        iconName: "app.fill",
        metric: "4.8"
    ),
    DiscoverItem(
        type: .article, size: .small,
        title: "SwiftUIで作るカスタムチャート",
        subtitle: "Charts不要の実装法",
        authorName: "佐藤健太", authorInitials: "佐",
        color: Color(red: 0.15, green: 0.2, blue: 0.3),
        iconName: "doc.text.fill",
        metric: "324"
    ),
    DiscoverItem(
        type: .video, size: .small,
        title: "Flutter vs SwiftUI 2026",
        subtitle: "12:34",
        authorName: "Emily Chen", authorInitials: "E",
        color: Color(red: 0.3, green: 0.18, blue: 0.25),
        iconName: "play.fill",
        metric: "1.2K"
    ),
    DiscoverItem(
        type: .codeSnippet, size: .small,
        title: "async/await エラーハンドリング",
        subtitle: "Swift Concurrency",
        authorName: "高橋リョウ", authorInitials: "高",
        color: Color(red: 0.12, green: 0.18, blue: 0.22),
        iconName: "chevron.left.forwardslash.chevron.right",
        metric: "89"
    ),
    DiscoverItem(
        type: .app, size: .small,
        title: "FocusFlow",
        subtitle: "ポモドーロタイマー",
        authorName: "Alex Kim", authorInitials: "A",
        color: Color(red: 0.25, green: 0.15, blue: 0.35),
        iconName: "app.fill",
        metric: "4.5"
    ),
    DiscoverItem(
        type: .article, size: .tall,
        title: "個人開発で月10万円稼ぐまでの全記録",
        subtitle: "収益化の実体験",
        authorName: "Maria Santos", authorInitials: "M",
        color: Color(red: 0.18, green: 0.22, blue: 0.18),
        iconName: "doc.text.fill",
        metric: "2.1K"
    ),
    DiscoverItem(
        type: .video, size: .tall,
        title: "0からiOSアプリをリリースするまで",
        subtitle: "45:12",
        authorName: "Jake Wilson", authorInitials: "J",
        color: Color(red: 0.28, green: 0.15, blue: 0.15),
        iconName: "play.fill",
        metric: "5.6K"
    ),
    DiscoverItem(
        type: .codeSnippet, size: .small,
        title: "matchedGeometryEffect 実践パターン",
        subtitle: "SwiftUI Animation",
        authorName: "鈴木一郎", authorInitials: "鈴",
        color: Color(red: 0.1, green: 0.15, blue: 0.2),
        iconName: "chevron.left.forwardslash.chevron.right",
        metric: "156"
    ),
    DiscoverItem(
        type: .app, size: .small,
        title: "CodeLog",
        subtitle: "開発ジャーナル",
        authorName: "Yuki Tanaka", authorInitials: "Y",
        color: Color(red: 0.2, green: 0.2, blue: 0.35),
        iconName: "app.fill",
        metric: "4.2"
    ),
    DiscoverItem(
        type: .article, size: .small,
        title: "Supabase認証完全ガイド",
        subtitle: "SwiftUI + Auth",
        authorName: "田中ゆうき", authorInitials: "田",
        color: Color(red: 0.15, green: 0.25, blue: 0.2),
        iconName: "doc.text.fill",
        metric: "890"
    ),
    DiscoverItem(
        type: .video, size: .small,
        title: "Rust入門 ライブコーディング",
        subtitle: "1:23:45",
        authorName: "高橋リョウ", authorInitials: "高",
        color: Color(red: 0.22, green: 0.12, blue: 0.18),
        iconName: "play.fill",
        metric: "3.4K"
    ),
    DiscoverItem(
        type: .app, size: .tall,
        title: "DevBoard",
        subtitle: "エンジニア向けダッシュボード",
        authorName: "Alex Kim", authorInitials: "A",
        color: Color(red: 0.15, green: 0.2, blue: 0.32),
        iconName: "app.fill",
        metric: "4.7"
    ),
]

// MARK: - Discover View

struct DiscoverView: View {
    @State private var searchText = ""
    @Binding var tabBarOffset: CGFloat

    @State private var headerOffset: CGFloat = 0
    private let headerHeight: CGFloat = 56

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                MasonryGrid(items: discoverItems)
                    .padding(.horizontal, 12)
                    .padding(.top, headerHeight + 8)
                    .padding(.bottom, 100)
            }
            .scrollIndicators(.hidden)
            .onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { oldValue, newValue in
                DispatchQueue.main.async {
                    let delta = newValue - oldValue
                    guard newValue > 0 else {
                        headerOffset = 0
                        tabBarOffset = 0
                        return
                    }
                    headerOffset = min(0, max(-headerHeight, headerOffset - delta))
                    tabBarOffset = min(90, max(0, tabBarOffset + delta))
                }
            }

            searchHeader
                .offset(y: headerOffset)
        }
        .background(Color.clBackground)
        .navigationBarHidden(true)
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)

            Text("ユーザー、タグ、アプリを検索")
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
        case .app: return ("app.fill", "App")
        case .article: return ("doc.text.fill", "記事")
        case .video: return ("play.fill", "動画")
        case .codeSnippet: return ("chevron.left.forwardslash.chevron.right", "Code")
        }
    }

    @ViewBuilder
    private var metricLabel: some View {
        switch item.type {
        case .app:
            HStack(spacing: 2) {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Color(red: 0.85, green: 0.65, blue: 0.13))
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
