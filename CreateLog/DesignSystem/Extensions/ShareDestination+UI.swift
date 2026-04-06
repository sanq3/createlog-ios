import SwiftUI

extension SharePlatform {
    var brandColor: Color {
        switch self {
        case .line: .clBrandLine
        case .instagram: .clBrandInstagram
        case .x: .primary
        case .discord: .clBrandDiscord
        case .github: .primary
        case .messages: .green
        case .mail: .blue
        }
    }

    var iconForeground: Color { .white }
}

extension ShareDestination {
    var brandColor: Color { platform.brandColor }
    var iconForeground: Color { platform.iconForeground }

    var isAvailable: Bool {
        guard let scheme = urlScheme,
              let url = URL(string: "\(scheme)://")
        else { return true }
        return UIApplication.shared.canOpenURL(url)
    }

    func share(url: String) {
        let shareText = "CreateLogで繋がろう! \(url)"
        let urlString = shareURL(shareText)
        guard let shareURL = URL(string: urlString) else { return }
        UIApplication.shared.open(shareURL)
    }
}
