import SwiftUI

struct ShareDestination: Identifiable {
    let id: String
    let label: String
    let assetIcon: String?
    let systemIcon: String
    let brandColor: Color
    let urlScheme: String?
    let shareURL: (String) -> String
    var iconForeground: Color = .white

    var isAvailable: Bool {
        guard let scheme = urlScheme,
              let url = URL(string: "\(scheme)://")
        else { return true } // No scheme check = always available (messages, mail)
        return UIApplication.shared.canOpenURL(url)
    }

    func share(url: String) {
        let shareText = "CreateLogで繋がろう! \(url)"
        let urlString = shareURL(shareText)
        guard let shareURL = URL(string: urlString) else { return }
        UIApplication.shared.open(shareURL)
    }
}

extension String {
    var encodedForURL: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
