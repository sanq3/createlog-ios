import SwiftUI
import SwiftData

/// ローカル SDProject の読み取り専用詳細画面。
/// ProfileView / UserProfileView のカードタップから遷移。
/// 編集・画像追加機能は v2.1 で別途実装。
struct SDProjectDetailView: View {
    let project: SDProject

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                if !project.appDescription.isEmpty {
                    descriptionSection
                }
                if !project.platforms.isEmpty {
                    platformsSection
                }
                if !project.techStack.isEmpty {
                    techStackSection
                }
                linkSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.clBackground)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            iconView
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 10, y: 4)

            HStack(spacing: 10) {
                Text(project.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.clTextPrimary)

                statusBadge
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var iconView: some View {
        if let data = project.iconImageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let urlString = project.remoteIconUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                default:
                    iconFallback
                }
            }
        } else {
            iconFallback
        }
    }

    private var iconFallback: some View {
        LinearGradient(
            colors: [project.iconColor, project.iconColor.opacity(0.7)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Text(project.iconInitial)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        )
    }

    private var statusBadge: some View {
        Text(project.status.displayName)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(statusForeground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusBackground, in: Capsule())
    }

    private var statusForeground: Color {
        switch project.status {
        case .draft: Color.clTextSecondary
        case .published: Color.clAccent
        case .archived: Color.clTextTertiary
        }
    }

    private var statusBackground: Color {
        switch project.status {
        case .draft: Color.clSurfaceHigh
        case .published: Color.clAccent.opacity(0.12)
        case .archived: Color.clSurfaceHigh.opacity(0.6)
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("紹介")
            Text(project.appDescription)
                .font(.subheadline)
                .foregroundStyle(Color.clTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
        }
    }

    // MARK: - Platforms

    private var platformsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("プラットフォーム")
            FlowLayout(spacing: 8) {
                ForEach(project.platforms, id: \.self) { platform in
                    chip(text: platform, foreground: Color.clTextPrimary, background: Color.clSurfaceHigh)
                }
            }
        }
    }

    // MARK: - Tech stack

    private var techStackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("技術スタック")
            FlowLayout(spacing: 8) {
                ForEach(project.techStack, id: \.self) { tech in
                    chip(text: tech, foreground: Color.clAccent, background: Color.clAccent.opacity(0.12))
                }
            }
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var linkSection: some View {
        let hasStore = project.storeURL?.isEmpty == false
        let hasGitHub = project.githubURL?.isEmpty == false
        if hasStore || hasGitHub {
            VStack(alignment: .leading, spacing: 10) {
                sectionTitle("リンク")
                VStack(spacing: 0) {
                    if let store = project.storeURL, !store.isEmpty {
                        linkRow(
                            icon: "arrow.up.right.square",
                            title: storeLabel,
                            url: store,
                            color: Color.clAccent
                        )
                    }
                    if hasStore && hasGitHub {
                        Divider().padding(.horizontal, 14)
                    }
                    if let github = project.githubURL, !github.isEmpty {
                        linkRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            title: "GitHub",
                            url: github,
                            color: Color.clTextPrimary
                        )
                    }
                }
                .background(Color.clSurfaceLow, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.clBorder, lineWidth: 1)
                )
            }
        }
    }

    private var storeLabel: String {
        guard let url = project.storeURL?.lowercased() else { return "Web" }
        if url.contains("apps.apple.com") { return "App Store" }
        if url.contains("play.google.com") { return "Google Play" }
        return "Web"
    }

    @ViewBuilder
    private func linkRow(icon: String, title: String, url: String, color: Color) -> some View {
        Button {
            if let destination = URL(string: url) {
                openURL(destination)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.clTextPrimary)
                    Text(url)
                        .font(.caption)
                        .foregroundStyle(Color.clTextTertiary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.clTextTertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Common

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.clHeadline)
            .foregroundStyle(Color.clTextSecondary)
    }

    private func chip(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(background, in: Capsule())
    }
}

// MARK: - FlowLayout

/// 改行自動の chip 並べ。iOS 16+ の Layout protocol 採用。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if lineWidth + size.width > maxWidth {
                totalHeight += lineHeight + spacing
                totalWidth = max(totalWidth, lineWidth - spacing)
                lineWidth = size.width + spacing
                lineHeight = size.height
            } else {
                lineWidth += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }
        }
        totalHeight += lineHeight
        totalWidth = max(totalWidth, lineWidth - spacing)
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
