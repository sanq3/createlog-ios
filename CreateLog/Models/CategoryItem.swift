import Foundation

struct CategoryItem: Identifiable {
    let id = UUID()
    let name: String
    let hours: Double
    let percentage: Double
}
