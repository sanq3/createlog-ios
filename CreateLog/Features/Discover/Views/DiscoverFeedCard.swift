import SwiftUI

/// Discover masonry feed の個別タイル。
/// FeedItem (Post / Project) を受け取り、2 列 masonry に収まるサイズで描画する。
struct DiscoverFeedCard: View {
    let item: FeedItem

    private var visualHeight: CGFloat {
        switch item.masonrySize {
        case .small: return 160
        case .tall: return 280
        }
    }

    var body: some View {
        NavigationLink { destinationView } label: {
            VStack(alignment: .leading, spacing: 0) {
                visualArea
                    .frame(height: visualHeight)
                    .clipped()

                infoArea
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.clBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { HapticManager.light() })
    }

    // MARK: - Visual

    @ViewBuilder
    private var visualArea: some View {
        ZStack(alignment: .topTrailing) {
            background
            if let badge = typeBadge {
                badge.padding(8)
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        switch item {
        case .post(let post):
            postBackground(post: post)
        case .project(let project):
            projectBackground(project: project)
        }
    }

    @ViewBuilder
    private func postBackground(post: Post) -> some View {
        if let media = post.media {
            switch media {
            case .images(let images):
                if let first = images.first, let url = first.thumbUrl ?? first.url, let parsed = URL(string: url) {
                    AsyncImage(url: parsed) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            placeholderFill(for: post.id, icon: "photo.fill")
                        }
                    }
                } else {
                    placeholderFill(for: post.id, icon: "photo.fill")
                }
            case .video:
                placeholderFill(for: post.id, icon: "play.fill")
            case .code:
                placeholderFill(for: post.id, icon: "chevron.left.forwardslash.chevron.right")
            }
        } else {
            textPostBackground(post: post)
        }
    }

    @ViewBuilder
    private func projectBackground(project: Project) -> some View {
        if let iconUrl = project.iconUrl, let parsed = URL(string: iconUrl) {
            AsyncImage(url: parsed) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    placeholderFill(for: project.id, icon: "hammer.fill")
                }
            }
        } else {
            placeholderFill(for: project.id, icon: "hammer.fill")
        }
    }

    @ViewBuilder
    private func placeholderFill(for seed: UUID, icon: String) -> some View {
        Self.paletteColor(for: seed)
            .overlay(
                Image(systemName: icon)
                    .font(.system(size: item.masonrySize == .tall ? 36 : 26, weight: .regular))
                    .foregroundStyle(.white.opacity(0.18))
            )
    }

    @ViewBuilder
    private func textPostBackground(post: Post) -> some View {
        Self.paletteColor(for: post.id)
            .overlay(alignment: .bottomLeading) {
                Text(post.content)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(item.masonrySize == .tall ? 6 : 3)
                    .multilineTextAlignment(.leading)
                    .padding(12)
            }
    }

    // MARK: - Badge

    private var typeBadge: AnyView? {
        switch item {
        case .post(let post):
            guard let media = post.media else { return nil }
            switch media {
            case .images: return nil
            case .video: return AnyView(badgeView(icon: "play.fill", label: "media.video"))
            case .code: return AnyView(badgeView(icon: "chevron.left.forwardslash.chevron.right", label: "Code"))
            }
        case .project:
            return AnyView(badgeView(icon: "arrow.up.right", label: "project.title"))
        }
    }

    private func badgeView(icon: String, label: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .bold))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.black.opacity(0.5))
                .background(.ultraThinMaterial, in: Capsule())
        )
    }

    // MARK: - Info

    private var infoArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.clTextPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 6) {
                AvatarView(
                    initials: authorInitials,
                    size: 16,
                    imageURL: authorAvatarURL
                )

                Text(authorName)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.clTextTertiary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.clTextTertiary)
                    Text(metricText)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.clTextTertiary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.clSurfaceLow)
    }

    // MARK: - Derived

    private var title: String {
        switch item {
        case .post(let post):
            return post.content.isEmpty ? "(本文なし)" : post.content
        case .project(let project):
            return project.name
        }
    }

    private var authorName: String {
        switch item {
        case .post(let post): return post.name
        case .project(let project): return project.authorName
        }
    }

    private var authorInitials: String {
        switch item {
        case .post(let post): return post.initials
        case .project(let project): return project.authorInitials.isEmpty ? "?" : project.authorInitials
        }
    }

    private var authorAvatarURL: URL? {
        switch item {
        case .post(let post):
            return post.authorAvatarUrl.flatMap(URL.init(string:))
        case .project(let project):
            return project.authorAvatarUrl.flatMap(URL.init(string:))
        }
    }

    private var metricText: String {
        switch item {
        case .post(let post): return compactCount(post.likes)
        case .project(let project): return compactCount(project.likes)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch item {
        case .post(let post):
            PostDetailView(post: post)
        case .project:
            // Phase B で SDProjectDetailView / ProjectDetailView を刷新するまでは簡易詳細を避け、戻すだけにする。
            EmptyView()
        }
    }

    // MARK: - Helpers

    /// id hash → clCat01..12 palette から deterministic に色を選ぶ。
    /// カテゴリパレットを流用 (発明しない)。同じ tile は常に同じ色。
    static func paletteColor(for id: UUID) -> Color {
        let hash = abs(id.hashValue) % 12
        switch hash {
        case 0: return .clCat01
        case 1: return .clCat02
        case 2: return .clCat03
        case 3: return .clCat04
        case 4: return .clCat05
        case 5: return .clCat06
        case 6: return .clCat07
        case 7: return .clCat08
        case 8: return .clCat09
        case 9: return .clCat10
        case 10: return .clCat11
        default: return .clCat12
        }
    }

    private func compactCount(_ value: Int) -> String {
        if value >= 1000 {
            let k = Double(value) / 1000.0
            return String(format: "%.1fK", k)
        }
        return "\(value)"
    }
}
