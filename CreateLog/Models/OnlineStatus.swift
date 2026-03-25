import SwiftUI

enum OnlineStatus {
    case online, coding, offline

    var color: Color {
        switch self {
        case .online: return .clSuccess
        case .coding: return .clRecording
        case .offline: return .clear
        }
    }
}
