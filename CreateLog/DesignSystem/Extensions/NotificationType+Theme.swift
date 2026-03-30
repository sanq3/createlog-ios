import SwiftUI

extension NotificationType {
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .follow: return "person.fill.badge.plus"
        case .repost: return "arrow.2.squarepath"
        case .comment: return "bubble.left.fill"
        case .mention: return "at"
        case .system: return "bell.fill"
        }
    }

    var color: Color {
        switch self {
        case .like: return .clError
        case .follow: return .clRecording
        case .repost: return .clSuccess
        case .comment: return .clAccent
        case .mention: return .clAccent
        case .system: return .clTextTertiary
        }
    }

    var filterLabel: String {
        switch self {
        case .like: return "いいね"
        case .follow: return "フォロー"
        case .repost: return "リポスト"
        case .comment: return "コメント"
        case .mention: return "メンション"
        case .system: return "システム"
        }
    }

    /// タイプ別バッジアイコン（アバター右下に表示）
    var badgeIcon: String {
        switch self {
        case .like: return "heart.fill"
        case .follow: return "plus"
        case .repost: return "arrow.2.squarepath"
        case .comment: return "bubble.fill"
        case .mention: return "at"
        case .system: return "megaphone.fill"
        }
    }
}

// MARK: - Avatar Colors

extension NotificationItem {
    /// イニシャルアバター用のカラーパレット
    static let avatarPalette: [Color] = [
        Color(red: 0.35, green: 0.56, blue: 0.97),  // Blue
        Color(red: 0.90, green: 0.45, blue: 0.45),  // Red
        Color(red: 0.40, green: 0.78, blue: 0.58),  // Green
        Color(red: 0.85, green: 0.60, blue: 0.30),  // Orange
        Color(red: 0.65, green: 0.45, blue: 0.85),  // Purple
        Color(red: 0.45, green: 0.72, blue: 0.82),  // Teal
    ]

    var avatarBackgroundColor: Color {
        Self.avatarPalette[avatarColor % Self.avatarPalette.count]
    }

    /// 名前の頭文字（日本語は最初の1文字、英語は大文字1文字）
    var avatarInitial: String {
        guard let first = primaryActor.first else { return "?" }
        return String(first).uppercased()
    }
}
