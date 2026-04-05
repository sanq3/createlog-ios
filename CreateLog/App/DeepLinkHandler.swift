import Foundation

/// ディープリンクのルーティング
enum DeepLink: Equatable {
    case post(id: UUID)
    case profile(handle: String)
    case notifications
    case record

    /// URL からパース
    static func parse(_ url: URL) -> DeepLink? {
        let components = url.pathComponents.filter { $0 != "/" }

        // createlog://post/{id}
        if components.first == "post", let idString = components.dropFirst().first, let id = UUID(uuidString: idString) {
            return .post(id: id)
        }

        // createlog://profile/{handle}
        if components.first == "profile", let handle = components.dropFirst().first {
            return .profile(handle: handle)
        }

        // createlog://notifications
        if components.first == "notifications" {
            return .notifications
        }

        // createlog://record
        if components.first == "record" {
            return .record
        }

        return nil
    }
}

/// ディープリンクの状態管理
@MainActor @Observable
final class DeepLinkHandler {
    var pendingLink: DeepLink?

    func handle(_ url: URL) {
        pendingLink = DeepLink.parse(url)
    }

    func consume() -> DeepLink? {
        let link = pendingLink
        pendingLink = nil
        return link
    }
}
