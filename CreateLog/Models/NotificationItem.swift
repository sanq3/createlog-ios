import Foundation

enum NotificationType {
    case like
    case follow
    case repost
    case reaction
}

struct NotificationItem: Identifiable {
    let id = UUID()
    let type: NotificationType
    let actor: String
    let message: String
    let time: String
}
