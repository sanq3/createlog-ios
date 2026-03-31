import Foundation

struct LogEntry: Identifiable {
    let id: UUID
    let title: String
    let categoryName: String
    let startHour: Double
    let endHour: Double
    let memo: String?
    let isAutoTracked: Bool

    init(
        id: UUID = UUID(),
        title: String,
        categoryName: String,
        startHour: Double,
        endHour: Double,
        memo: String? = nil,
        isAutoTracked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.categoryName = categoryName
        self.startHour = startHour
        self.endHour = endHour
        self.memo = memo
        self.isAutoTracked = isAutoTracked
    }

    var durationMinutes: Int {
        Int((endHour - startHour) * 60)
    }

    var durationString: String {
        DurationFormatter.format(minutes: durationMinutes)
    }

    var startTimeString: String {
        let h = Int(startHour)
        let m = Int((startHour - Double(h)) * 60)
        return String(format: "%d:%02d", h, m)
    }

    var endTimeString: String {
        let h = Int(endHour)
        let m = Int((endHour - Double(h)) * 60)
        return String(format: "%d:%02d", h, m)
    }

    var timeRangeString: String {
        "\(startTimeString) - \(endTimeString)"
    }
}
