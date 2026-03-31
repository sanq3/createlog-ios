import Foundation

enum RelativeTimeFormatter {
    static func format(from date: Date, relativeTo now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        if minutes < 1 { return DurationFormatter.isJapanese ? "たった今" : "Just now" }
        if minutes < 60 { return DurationFormatter.isJapanese ? "\(minutes)分前" : "\(minutes)m ago" }
        if hours < 24 { return DurationFormatter.isJapanese ? "\(hours)時間前" : "\(hours)h ago" }
        if days < 7 { return DurationFormatter.isJapanese ? "\(days)日前" : "\(days)d ago" }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}
