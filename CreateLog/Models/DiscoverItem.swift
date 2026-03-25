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
