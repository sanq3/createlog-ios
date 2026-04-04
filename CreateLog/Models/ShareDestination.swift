import Foundation

enum SharePlatform: String, CaseIterable, Sendable {
    case line, instagram, x, discord, github, messages, mail
}

struct ShareDestination: Identifiable {
    let id: String
    let label: String
    let assetIcon: String?
    let systemIcon: String
    let platform: SharePlatform
    let urlScheme: String?
    let shareURL: (String) -> String
}

extension String {
    var encodedForURL: String {
        addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
