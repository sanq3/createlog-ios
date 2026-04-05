import SwiftUI

struct ProjectDetailView: View {
    let project: Project

    private var reviews: [Review] {
        #if DEBUG
        return MockData.reviews
        #else
        return []
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                metaSection
                screenshotSection
                linkSection
                reviewSection
                tagSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.clBackground)
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 14) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: project.iconColor.red, green: project.iconColor.green, blue: project.iconColor.blue),
                            Color(
                                red: project.iconColor.red * 0.6,
                                green: project.iconColor.green * 0.6,
                                blue: project.iconColor.blue * 0.6
                            ),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay(
                    Text(project.iconInitials)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                )
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                )
                .shadow(
                    color: Color(
                        red: project.iconColor.red,
                        green: project.iconColor.green,
                        blue: project.iconColor.blue
                    ).opacity(0.4),
                    radius: 10, y: 4
                )

            Text(project.name)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.clTextPrimary)

            Text(project.description)
                .font(.subheadline)
                .foregroundStyle(Color.clTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Meta

    private var metaSection: some View {
        detailCard {
            HStack(spacing: 16) {
                metaBadge(icon: project.platform.iconName, text: project.platform.rawValue)

                Divider()
                    .frame(height: 20)

                HStack(spacing: 4) {
                    AvatarView(initials: project.authorInitials, size: 22)
                    Text(project.authorName)
                        .font(.caption)
                        .foregroundStyle(Color.clTextSecondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", project.averageRating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.clTextPrimary)
                    Text("(\(project.reviewCount))")
                        .font(.caption)
                        .foregroundStyle(Color.clTextTertiary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Color.clError)
                    Text("\(project.likes)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.clTextPrimary)
                }
            }
        }
    }

    private func metaBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.clAccent)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(Color.clTextPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.clAccent.opacity(0.12))
        )
    }

    // MARK: - Screenshots

    @ViewBuilder
    private var screenshotSection: some View {
        if !project.screenshotColors.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("スクリーンショット")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(project.screenshotColors.enumerated()), id: \.offset) { _, color in
                            RoundedRectangle(cornerRadius: 18)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: color.red, green: color.green, blue: color.blue),
                                            Color(red: color.red * 0.7, green: color.green * 0.7, blue: color.blue * 1.3),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 160, height: 280)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18)
                                        .strokeBorder(.white.opacity(0.06), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Links

    @ViewBuilder
    private var linkSection: some View {
        if project.storeURL != nil || project.githubURL != nil {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("リンク")

                detailCard {
                    VStack(spacing: 12) {
                        if let storeURL = project.storeURL {
                            linkRow(
                                icon: "arrow.up.right.square",
                                title: "ストアページ",
                                url: storeURL,
                                color: Color.clAccent
                            )
                        }

                        if project.storeURL != nil, project.githubURL != nil {
                            Divider()
                        }

                        if let githubURL = project.githubURL {
                            linkRow(
                                icon: "chevron.left.forwardslash.chevron.right",
                                title: "GitHub",
                                url: githubURL,
                                color: Color.clTextPrimary
                            )
                        }
                    }
                }
            }
        }
    }

    private func linkRow(icon: String, title: String, url: String, color: Color) -> some View {
        Button {
            HapticManager.light()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(color.opacity(0.1))
                    )

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
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reviews

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("レビュー")

            // Rating summary
            detailCard {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(String(format: "%.1f", project.averageRating))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.clTextPrimary)

                        starsView(rating: project.averageRating)

                        Text("\(project.reviewCount)件のレビュー")
                            .font(.caption)
                            .foregroundStyle(Color.clTextTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            // Review list
            ForEach(reviews) { review in
                reviewCard(review)
            }

            // Request review button (Coming Soon)
            Button {
                // v2.1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "star.bubble")
                        .font(.system(size: 16))
                    Text("レビューを依頼する")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(Color.clTextTertiary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.clSurfaceLow)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(Color.clBorder, lineWidth: 1)
                        )
                )
                .overlay(alignment: .topTrailing) {
                    Text("Coming Soon")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.clAccent.opacity(0.7))
                        )
                        .offset(x: -8, y: -8)
                }
            }
            .buttonStyle(.plain)
            .disabled(true)
        }
    }

    private func reviewCard(_ review: Review) -> some View {
        detailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    AvatarView(initials: review.authorInitials, size: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(review.authorName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.clTextPrimary)
                        Text("@\(review.authorHandle)")
                            .font(.caption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer()

                    starsView(rating: Double(review.rating), size: 12)
                }

                if !review.text.isEmpty {
                    Text(review.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.clTextSecondary)
                        .lineLimit(4)
                }

                Text(review.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(Color.clTextTertiary)

                if let reply = review.developerReply {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.system(size: 10))
                            Text("開発者の返信")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(Color.clAccent)

                        Text(reply)
                            .font(.caption)
                            .foregroundStyle(Color.clTextSecondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.clAccent.opacity(0.06))
                    )
                }
            }
        }
    }

    private func starsView(rating: Double, size: CGFloat = 14) -> some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starImageName(for: index, rating: rating))
                    .font(.system(size: size))
                    .foregroundStyle(index <= Int(rating.rounded()) ? .yellow : Color.clTextTertiary.opacity(0.3))
            }
        }
    }

    private func starImageName(for index: Int, rating: Double) -> String {
        let floored = Int(rating)
        if index <= floored {
            return "star.fill"
        } else if index == floored + 1, rating - Double(floored) >= 0.5 {
            return "star.leadinghalf.filled"
        } else {
            return "star"
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private var tagSection: some View {
        if !project.tags.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("タグ")

                FlowLayout(spacing: 8) {
                    ForEach(project.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.subheadline)
                            .foregroundStyle(Color.clAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(Color.clAccent.opacity(0.1))
                                    .overlay(
                                        Capsule()
                                            .strokeBorder(Color.clAccent.opacity(0.2), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(Color.clTextPrimary)
            .padding(.horizontal, 4)
    }

    private func detailCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color.clSurfaceHigh)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(Color.clBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.08), radius: 16, y: 6)
            )
    }
}

// MARK: - WrappingHStack


#if DEBUG
#Preview {
    NavigationStack {
        ProjectDetailView(project: MockData.projects[0])
    }
    .preferredColorScheme(.dark)
}
#endif
