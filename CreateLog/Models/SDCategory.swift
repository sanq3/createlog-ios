import SwiftData
import Foundation

@Model
final class SDCategory {
    var name: String
    var colorIndex: Int
    var isStandard: Bool
    var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \SDProject.category)
    var projects: [SDProject] = []

    init(name: String, colorIndex: Int, isStandard: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.colorIndex = colorIndex
        self.isStandard = isStandard
        self.sortOrder = sortOrder
    }

    var colorName: String {
        "clCat\(String(format: "%02d", colorIndex))"
    }
}

@Model
final class SDProject {
    var name: String
    var category: SDCategory?
    var createdAt: Date

    init(name: String, category: SDCategory? = nil) {
        self.name = name
        self.category = category
        self.createdAt = Date()
    }
}

@Model
final class SDTimeEntry {
    var startDate: Date
    var endDate: Date?
    var durationMinutes: Int
    var projectName: String
    var categoryName: String
    var memo: String?

    init(startDate: Date, endDate: Date? = nil, durationMinutes: Int = 0,
         projectName: String, categoryName: String, memo: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.durationMinutes = durationMinutes
        self.projectName = projectName
        self.categoryName = categoryName
        self.memo = memo
    }
}
