import Foundation

struct CategoryBreakdownItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let minutes: Int
}
