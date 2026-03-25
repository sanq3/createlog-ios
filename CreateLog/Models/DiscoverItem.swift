import SwiftUI

enum DiscoverContentType {
    case project
    case article
    case video
    case codeSnippet
}

enum DiscoverCardSize {
    case small
    case tall
    case wide

    var height: CGFloat {
        switch self {
        case .small: return 180
        case .tall: return 280
        case .wide: return 180
        }
    }
}

struct DiscoverItem: Identifiable {
    let id = UUID()
    let type: DiscoverContentType
    let size: DiscoverCardSize
    let title: String
    let subtitle: String
    let authorName: String
    let authorInitials: String
    let color: Color
    let iconName: String
    let metric: String
}
