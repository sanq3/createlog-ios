import SwiftUI

struct Post: Identifiable {
    let id = UUID()
    let name: String
    let handle: String
    let initials: String
    let status: OnlineStatus
    let workTime: String
    let content: String
    let timeAgo: String
    var likes: Int
    var reposts: Int
    var comments: Int
    var isLiked: Bool = false
}
