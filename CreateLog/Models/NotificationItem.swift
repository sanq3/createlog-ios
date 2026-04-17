import Foundation

enum NotificationType: CaseIterable {
    case like
    case follow
    case repost
    case comment
    case mention
    case system
}

enum NotificationTimeSection: String {
    case new = "新着"
    case today = "recording.today"
    case thisWeek = "recording.thisWeek"
    case earlier = "それ以前"
}

struct NotificationItem: Identifiable, Sendable {
    let id: UUID
    let type: NotificationType
    let primaryActor: String
    let groupedActors: [String]
    let message: String
    let timestamp: Date
    let isRead: Bool
    let contentPreview: String?
    let avatarColor: Int

    init(
        id: UUID = UUID(),
        type: NotificationType,
        primaryActor: String,
        groupedActors: [String] = [],
        message: String,
        timestamp: Date,
        isRead: Bool = false,
        contentPreview: String? = nil
    ) {
        self.id = id
        self.type = type
        self.primaryActor = primaryActor
        self.groupedActors = groupedActors
        self.message = message
        self.timestamp = timestamp
        self.isRead = isRead
        self.contentPreview = contentPreview
        // 名前から決定的にカラーインデックスを生成
        self.avatarColor = abs(primaryActor.hashValue) % 6
    }

    var isSystemNotification: Bool {
        type == .system
    }

    var totalActorCount: Int {
        1 + groupedActors.count
    }

    var actorDisplayText: String {
        if groupedActors.isEmpty {
            return primaryActor
        }
        let othersCount = groupedActors.count
        return "\(primaryActor)と他\(othersCount)人"
    }

    var timeSection: NotificationTimeSection {
        let calendar = Calendar.current
        let now = Date()

        if !isRead {
            return .new
        }
        if calendar.isDateInToday(timestamp) {
            return .today
        }
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        if timestamp > weekAgo {
            return .thisWeek
        }
        return .earlier
    }

    var relativeTimeText: String {
        RelativeTimeFormatter.format(from: timestamp)
    }
}
