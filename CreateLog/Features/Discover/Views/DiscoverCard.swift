import SwiftUI

// MARK: - Card

struct DiscoverCard: View {
    let item: DiscoverItem

    var body: some View {
        Button {
            HapticManager.light()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Visual area
                ZStack(alignment: .topTrailing) {
                    // Gradient background
                    LinearGradient(
                        colors: [
                            item.placeholderColor.color,
                            item.placeholderColor.color.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: item.iconName)
                                .font(.system(size: item.size == .tall ? 32 : 24))
                                .foregroundStyle(.white.opacity(0.12))
                        }
                    )

                    // Type badge
                    typeBadge
                        .padding(8)
                }
                .frame(height: item.size.height - 64)
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
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
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
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: Capsule())
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
        let icon = item.type == .video ? "eye.fill" : "heart.fill"
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(Color.clTextTertiary)
            Text(item.metric)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color.clTextTertiary)
        }
    }
}
