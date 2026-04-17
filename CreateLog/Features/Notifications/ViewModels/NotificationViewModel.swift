import Foundation

/// 通知画面のViewModel
@MainActor @Observable
final class NotificationViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let repository: any NotificationRepositoryProtocol

    // MARK: - State

    enum Filter: Int, CaseIterable {
        case all = 0, like, follow, mention, system

        var label: String {
            switch self {
            case .all: "すべて"
            case .like: "いいね"
            case .follow: "フォロー"
            case .mention: "メンション"
            case .system: "システム"
            }
        }

        var notificationType: NotificationType? {
            switch self {
            case .all: nil
            case .like: .like
            case .follow: .follow
            case .mention: .mention
            case .system: .system
            }
        }
    }

    var filter: Filter = .all
    /// UIで使用するドメイン型
    var notifications: [NotificationItem] = []
    var unreadCount = 0
    var isLoading = false
    var hasMore = true

    @ObservationIgnored private var oldestCursor: Date?

    // MARK: - Init

    init(repository: any NotificationRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Computed

    var filteredNotifications: [NotificationItem] {
        guard let type = filter.notificationType else { return notifications }
        return notifications.filter { $0.type == type }
    }

    // MARK: - Actions

    func loadNotifications() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let dtos = try await repository.fetchNotifications(cursor: nil, limit: AppConfig.feedPageSize)
            notifications = dtos.map { NotificationItem(from: $0) }
            oldestCursor = dtos.last?.createdAt
            unreadCount = try await repository.fetchUnreadCount()
            hasMore = dtos.count >= AppConfig.feedPageSize
        } catch {
            // キープ現状
        }
    }

    func loadMore() async {
        guard hasMore, let cursor = oldestCursor else { return }
        do {
            let dtos = try await repository.fetchNotifications(cursor: cursor, limit: AppConfig.feedPageSize)
            notifications.append(contentsOf: dtos.map { NotificationItem(from: $0) })
            oldestCursor = dtos.last?.createdAt ?? oldestCursor
            hasMore = dtos.count >= AppConfig.feedPageSize
        } catch {
            // サイレント
        }
    }

    func markAsRead(_ notification: NotificationItem) async {
        guard !notification.isRead else { return }
        do {
            try await repository.markAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                let current = notifications[index]
                // NotificationItemはvarを持たないのでインスタンスを作り直す
                notifications[index] = NotificationItem(
                    id: current.id,
                    type: current.type,
                    primaryActor: current.primaryActor,
                    groupedActors: current.groupedActors,
                    message: current.message,
                    timestamp: current.timestamp,
                    isRead: true,
                    contentPreview: current.contentPreview
                )
                unreadCount = max(0, unreadCount - 1)
            }
        } catch {
            // サイレント
        }
    }

    func markAllAsRead() async {
        do {
            try await repository.markAllAsRead()
            notifications = notifications.map { n in
                NotificationItem(
                    id: n.id,
                    type: n.type,
                    primaryActor: n.primaryActor,
                    groupedActors: n.groupedActors,
                    message: n.message,
                    timestamp: n.timestamp,
                    isRead: true,
                    contentPreview: n.contentPreview
                )
            }
            unreadCount = 0
        } catch {
            // サイレント
        }
    }
}
