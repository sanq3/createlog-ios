import Foundation

/// 週間スタックチャート用のデータエントリ (日/カテゴリ/時間)
struct WeeklyStackedEntry: Identifiable, Sendable {
    let id: UUID
    let day: String
    let category: String
    let hours: Double

    init(id: UUID = UUID(), day: String, category: String, hours: Double) {
        self.id = id
        self.day = day
        self.category = category
        self.hours = hours
    }
}
