import Foundation

enum DurationFormat: String, CaseIterable {
    case system
    case japanese
    case english

    var label: String {
        switch self {
        case .system: "端末の設定に従う"
        case .japanese: "日本語 (1時間30分)"
        case .english: "English (1h 30m)"
        }
    }
}


enum DurationFormatter {
    static var isJapanese: Bool {
        let stored = UserDefaults.standard.string(forKey: "durationFormat") ?? DurationFormat.system.rawValue
        switch DurationFormat(rawValue: stored) ?? .system {
        case .japanese: return true
        case .english: return false
        case .system: return Locale.current.language.languageCode?.identifier == "ja"
        }
    }

    /// Format minutes (Int) into localized duration string
    static func format(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if isJapanese {
            if h > 0 && m > 0 { return "\(h)時間\(m)分" }
            if h > 0 { return "\(h)時間" }
            return "\(m)分"
        } else {
            if h > 0 && m > 0 { return "\(h)h \(m)m" }
            if h > 0 { return "\(h)h" }
            return "\(m)m"
        }
    }

    /// Format hours (Double) into localized duration string
    static func format(hours: Double) -> String {
        let h = Int(floor(hours))
        let m = Int((hours.truncatingRemainder(dividingBy: 1)) * 60)
        if isJapanese {
            if m > 0 { return "\(h)時間\(String(format: "%02d", m))分" }
            return "\(h)時間"
        } else {
            if m > 0 { return "\(h)h \(String(format: "%02d", m))m" }
            return "\(h)h"
        }
    }

    /// Format hours (Double) for chart axis labels (short form)
    static func formatAxisLabel(hours: Double) -> String {
        isJapanese ? "\(Int(hours))時間" : "\(Int(hours))h"
    }

    /// Format minutes (Int) for compact display (no space)
    static func formatCompact(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h >= 100 {
            return isJapanese ? "\(h)時間" : "\(h)h"
        }
        if m == 0 {
            return isJapanese ? "\(h)時間" : "\(h)h"
        }
        return isJapanese ? "\(h)時間\(m)分" : "\(h)h\(m)m"
    }

    /// Unit suffix for KPI display (e.g., "時間" or "h")
    static var hoursSuffix: String {
        isJapanese ? "時間" : "h"
    }

    /// Convert minutes to decimal hours string (e.g., 130 → "2.2")
    static func decimalHours(minutes: Int) -> String {
        let hours = Double(minutes) / 60.0
        return String(format: "%.1f", hours)
    }

    /// Convert minutes to h:mm format (e.g., 130 → "2:10", 5 → "0:05")
    static func colonFormat(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    /// Convert hours (Double) to h:mm format (e.g., 4.25 → "4:15")
    static func colonFormat(hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    /// Format hours (Double) in h/m notation (language-independent)
    /// e.g., 12.5 → "12h 30m", 5.0 → "5h"
    static func formatHM(hours: Double) -> String {
        let h = Int(floor(hours))
        let m = Int((hours.truncatingRemainder(dividingBy: 1)) * 60)
        if h > 0 && m > 0 { return "\(h)h \(String(format: "%02d", m))m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    /// Format minutes (Int) in h/m notation (language-independent)
    /// e.g., 130 → "2h 10m", 45 → "45m"
    static func formatHM(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    /// Locale for UIDatePicker based on current setting
    static var pickerLocale: Locale {
        isJapanese ? Locale(identifier: "ja_JP") : Locale(identifier: "en_US")
    }
}
