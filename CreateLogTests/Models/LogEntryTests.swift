import Testing
@testable import CreateLog

@Suite("LogEntry")
struct LogEntryTests {

    @Test("durationMinutesが正しく計算される")
    func durationMinutes() {
        let entry = LogEntry(
            title: "テスト作業",
            categoryName: "iOS開発",
            startHour: 9.0,
            endHour: 10.5
        )
        #expect(entry.durationMinutes == 90)
    }

    @Test("durationStringのフォーマット", arguments: [
        (9.0, 10.5, "1h 30m"),
        (9.0, 11.0, "2h"),
        (9.0, 9.5, "30m"),
    ])
    func durationString(start: Double, end: Double, expected: String) {
        let entry = LogEntry(
            title: "作業",
            categoryName: "開発",
            startHour: start,
            endHour: end
        )
        #expect(entry.durationString == expected)
    }

    @Test("timeRangeStringのフォーマット")
    func timeRangeString() {
        let entry = LogEntry(
            title: "作業",
            categoryName: "開発",
            startHour: 9.5,
            endHour: 12.0
        )
        #expect(entry.timeRangeString == "9:30 - 12:00")
    }

    @Test("デフォルト値")
    func defaults() {
        let entry = LogEntry(
            title: "作業",
            categoryName: "開発",
            startHour: 9.0,
            endHour: 10.0
        )
        #expect(entry.memo == nil)
        #expect(entry.isAutoTracked == false)
    }
}
