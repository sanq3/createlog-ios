import SwiftUI

extension SharePlatform {
    var brandColor: Color {
        switch self {
        case .line: Color(red: 0.0, green: 0.78, blue: 0.33)
        case .instagram: Color(red: 0.88, green: 0.19, blue: 0.42)
        case .x: .primary
        case .discord: Color(red: 0.35, green: 0.40, blue: 0.95)
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
