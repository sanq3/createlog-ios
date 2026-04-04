import Foundation

struct RecordingHeroMetrics: Equatable {
    let todayMinutes: Int
    let cumulativeMinutes: Int
    let weekChange: Double?
    let breakdown: [CategoryBreakdownItem]

    static let empty = RecordingHeroMetrics(
        todayMinutes: 0,
        cumulativeMinutes: 0,
        weekChange: nil,
        breakdown: []
    )
}
