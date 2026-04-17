import SwiftUI

struct NotificationsView: View {
    @Environment(\.dependencies) private var deps
    @State private var viewModel: NotificationViewModel?
    @State private var filterIndex = 0

    private let filterLabels = ["すべて", "いいね", "フォロー", "メンション", "システム"]

    private var allNotifications: [NotificationItem] {
        viewModel?.notifications ?? []
    }

    private var filteredNotifications: [NotificationItem] {
        guard filterIndex > 0 else { return allNotifications }
        let targetTypes: [NotificationType] = {
            switch filterIndex {
            case 1: return [.like]
            case 2: return [.follow]
            case 3: return [.mention]
            case 4: return [.system]
            default: return NotificationType.allCases
            }
        }()
        return allNotifications.filter { targetTypes.contains($0.type) }
    }

    private var groupedBySection: [(section: NotificationTimeSection, items: [NotificationItem])] {
        let sectionOrder: [NotificationTimeSection] = [.new, .today, .thisWeek, .earlier]
        let grouped = Dictionary(grouping: filteredNotifications) { $0.timeSection }
        return sectionOrder.compactMap { section in
            guard let items = grouped[section], !items.isEmpty else { return nil }
            return (section, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                CLSegmentedControl(
                    items: filterLabels,
                    selection: $filterIndex
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)

                if filteredNotifications.isEmpty {
                    emptyState
                } else {
                    notificationList
                }

                Spacer(minLength: 100)
            }
        }
        .scrollIndicators(.hidden)
        .background(Color.clBackground)
        .navigationTitle("notification.title")
        .refreshable {
            await viewModel?.loadNotifications()
        }
        .task {
            if viewModel == nil {
                viewModel = NotificationViewModel(repository: deps.notificationRepository)
            }
            await viewModel?.loadNotifications()
        }
    }

    // MARK: - Notification List

    private var notificationList: some View {
        LazyVStack(spacing: 0) {
            ForEach(groupedBySection, id: \.section) { section, items in
                Section {
                    ForEach(items) { notif in
                        notificationRow(notif)
                    }
                } header: {
                    sectionHeader(section)
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: NotificationTimeSection) -> some View {
        HStack {
            Text(section.rawValue)
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.clBackground)
    }

    // MARK: - Notification Row

    private func notificationRow(_ notif: NotificationItem) -> some View {
        Button {
            Task { await viewModel?.markAsRead(notif) }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    notificationIcon(notif)

                    VStack(alignment: .leading, spacing: 4) {
                        actorAndMessage(notif)

                        if let preview = notif.contentPreview {
                            Text(preview)
                                .font(.clCaption)
                                .foregroundStyle(Color.clTextTertiary)
                                .lineLimit(1)
                        }

                        Text(notif.relativeTimeText)
                            .font(.clCaption)
                            .foregroundStyle(Color.clTextTertiary)
                    }

                    Spacer(minLength: 0)

                    if !notif.isRead {
                        Circle()
                            .fill(Color.clAccent)
                            .frame(width: 8, height: 8)
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(notif.isRead ? Color.clear : Color.clAccent.opacity(0.05))

                Divider()
                    .overlay(Color.clBorder)
                    .padding(.leading, 76)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Avatar + Badge

    private func notificationIcon(_ notif: NotificationItem) -> some View {
        ZStack(alignment: .bottomTrailing) {
            if notif.isSystemNotification {
                // 運営通知: アプリアイコン風
                Circle()
                    .fill(Color.clSurfaceHigh)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("CL")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.clTextSecondary)
                    )
            } else {
                // ユーザー通知: イニシャルアバター
                Circle()
                    .fill(notif.avatarBackgroundColor)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(notif.avatarInitial)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }

            // タイプバッジ（右下）
            if !notif.isSystemNotification {
                Circle()
                    .fill(notif.type.color)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: notif.type.badgeIcon)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }

    // MARK: - Actor + Message

    @ViewBuilder
    private func actorAndMessage(_ notif: NotificationItem) -> some View {
        let actorText = Text(notif.actorDisplayText)
            .fontWeight(.semibold)
            .foregroundColor(Color.clTextPrimary)
        let messageText = Text(notif.message)
            .foregroundColor(Color.clTextSecondary)

        (actorText + messageText)
            .font(.clBody)
            .lineLimit(2)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(Color.clTextTertiary)

            Text("notification.empty")
                .font(.clHeadline)
                .foregroundStyle(Color.clTextSecondary)

            Text("notification.empty.description")
                .font(.clCaption)
                .foregroundStyle(Color.clTextTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 120)
    }
}
