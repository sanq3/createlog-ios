import SwiftUI

extension NotificationType {
    var icon: String {
        switch self {
        case .like: return "heart.fill"
        case .follow: return "person.fill.badge.plus"
        case .repost: return "arrow.2.squarepath"
        case .reaction: return "heart.fill"
        }
    }

    var color: Color {
        switch self {
        case .like: return .clError
        case .follow: return .clRecording
        case .repost: return .clSuccess
        case .reaction: return .clError
        }
    }
}
