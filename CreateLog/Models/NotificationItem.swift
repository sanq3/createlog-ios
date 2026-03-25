import SwiftUI

struct NotificationItem: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let actor: String
    let message: String
    let time: String
}
