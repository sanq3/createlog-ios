import SwiftUI

extension OnlineStatus {
    var color: Color {
        switch self {
        case .online: return .clSuccess
        case .coding: return .clRecording
        case .offline: return .clear
        }
    }
}
