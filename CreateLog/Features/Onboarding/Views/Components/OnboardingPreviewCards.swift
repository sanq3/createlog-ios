import SwiftUI

/// オンボーディング後半 (displayName → projectStatus) の下部に固定する
/// 「育っていく」プレビューカード 2 種。
/// - Profile 系 (displayName/handleSetup/avatar/bio/roleTag): `OnboardingProfilePreviewCard`
/// - Product 系 (projectIcon/URL/GitHub/description/status): `OnboardingProductPreviewCard`
///
/// 入力するたびにカードが即座に更新され、完成形に近づく体感を与える。
/// 空の field は薄い placeholder で表示し、入ったらクロスフェード / slide-in する。

// MARK: - Profile preview

struct OnboardingProfilePreviewCard: View {
    let displayName: String
    let handle: String
    let avatarData: Data?
    let bio: String
    let roleTags: [String]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                avatar
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    Text(effectiveDisplayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(displayName.isEmpty ? Color.clTextPrimary.opacity(0.35) : Color.clTextPrimary)
                        .lineLimit(1)
                        .contentTransition(.opacity)

                    Text(handle.isEmpty ? "@username" : "@" + handle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(handle.isEmpty ? Color.clTextPrimary.opacity(0.3) : Color.clTextPrimary.opacity(0.55))
                        .lineLimit(1)
                        .contentTransition(.opacity)
                }
                Spacer()
            }

            if !effectiveBio.isEmpty {
                Text(effectiveBio)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.7))
                    .lineLimit(2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !roleTags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(roleTags, id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.clAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.clAccent.opacity(0.12)))
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.6).combined(with: .opacity).combined(with: .offset(x: 20, y: 0)),
                                removal: .opacity
                            ))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, x: 0, y: 6)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: displayName)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: handle)
        .animation(.spring(duration: 0.5, bounce: 0.25), value: avatarData)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: bio)
        .animation(.spring(duration: 0.5, bounce: 0.25), value: roleTags)
    }

    private var effectiveDisplayName: String {
        displayName.isEmpty ? "あなたの名前" : displayName
    }

    private var effectiveBio: String {
        bio.isEmpty ? "" : bio
    }

    @ViewBuilder
    private var avatar: some View {
        if let data = avatarData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(Circle())
                .transition(.scale.combined(with: .opacity))
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            OnboardingAccountPromptStep.iconColor(for: displayName.isEmpty ? "User" : displayName),
                            OnboardingAccountPromptStep.iconColor(for: handle.isEmpty ? "Handle" : handle).opacity(0.7),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Text(String((displayName.isEmpty ? "?" : displayName).prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                )
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Product preview

struct OnboardingProductPreviewCard: View {
    let projectName: String
    let platform: String
    let iconData: Data?
    let storeURL: String
    let githubURL: String
    let appDescription: String
    let status: ProjectStatus?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                icon
                    .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(projectName.isEmpty ? "My Project" : projectName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.clTextPrimary)
                            .lineLimit(1)

                        if let status {
                            Text(status.displayName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(statusColor(for: status))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(statusColor(for: status).opacity(0.15)))
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.4).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }

                    Text(platform.isEmpty ? "iOS" : platform)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.clTextPrimary.opacity(0.55))
                        .lineLimit(1)
                }
                Spacer()

                HStack(spacing: 8) {
                    if !storeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "link")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.clAccent)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity).combined(with: .offset(x: 16, y: 0)),
                                removal: .opacity
                            ))
                    }
                    if !githubURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.clAccent)
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.4).combined(with: .opacity).combined(with: .offset(x: 16, y: 0)),
                                removal: .opacity
                            ))
                    }
                }
            }

            if !appDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(appDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.clTextPrimary.opacity(0.7))
                    .lineLimit(2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.clSurfaceHigh)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.clTextPrimary.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 16, x: 0, y: 6)
        .animation(.spring(duration: 0.5, bounce: 0.25), value: iconData)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: storeURL)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: githubURL)
        .animation(.spring(duration: 0.45, bounce: 0.15), value: appDescription)
        .animation(.spring(duration: 0.5, bounce: 0.3), value: status)
    }

    @ViewBuilder
    private var icon: some View {
        if let data = iconData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.scale.combined(with: .opacity))
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(OnboardingAccountPromptStep.iconColor(for: projectName.isEmpty ? "Project" : projectName))
                .overlay(
                    Text(String((projectName.isEmpty ? "?" : projectName).prefix(1)))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                )
                .transition(.scale.combined(with: .opacity))
        }
    }

    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .draft: return Color.clAccent
        case .published: return Color.clSuccess
        case .archived: return Color.clTextPrimary.opacity(0.5)
        }
    }
}
