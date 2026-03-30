import SwiftUI

extension LogEntry {
    var categoryColor: Color {
        Self.color(for: categoryName)
    }

    static func color(for categoryName: String) -> Color {
        switch categoryName {
        case "iOS開発": return Color("clCat01")     // Blue
        case "デザイン": return Color("clCat02")     // Pink
        case "学習": return Color("clCat03")         // Indigo
        case "バグ修正": return Color("clCat04")     // Orange
        case "Web開発": return Color("clCat05")      // Teal
        case "ミーティング": return Color("clCat06") // Green
        case "マーケティング": return Color("clCat08") // Cyan
        case "ライティング": return Color("clCat09") // Purple
        case "事務": return Color("clCat07")         // Gray
        default: return Color("clCat07")
        }
    }

    var categoryIcon: String {
        switch categoryName {
        case "iOS開発": return "chevron.left.forwardslash.chevron.right"
        case "Web開発": return "globe"
        case "学習": return "book.fill"
        case "バグ修正": return "ladybug.fill"
        case "デザイン": return "paintbrush.fill"
        default: return "folder.fill"
        }
    }
}
