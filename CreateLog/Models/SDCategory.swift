import SwiftData
import Foundation

@Model
final class SDCategory {
    // MARK: - Fields
    // 全プロパティに default 値を持たせる (SwiftData lightweight migration の必須要件)。
    // 新規 @Model (SDOfflineOperation) を Schema に追加した際に既存行の migration が
    // 失敗するのを防ぐため。init() は従来通りの必須引数を維持している。
    //
    // `colorIndex = 1` sentinel: Assets に存在する最小有効値 (clCat01〜clCat12 のみ定義、
    // clCat00 は asset 未定義)。万一 migration fallback で使われても色抜けしない保険。
    var name: String = ""
    var colorIndex: Int = 1
    var isStandard: Bool = false
    var sortOrder: Int = 0

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
    // MARK: - Fields
    // 全プロパティに default 値 (lightweight migration 要件)。
    var name: String = ""
    var platforms: [String] = []
    var techStack: [String] = []
    var category: SDCategory?
    var createdAt: Date = Date()

    // Onboarding projectDetail (2026-04-14)
    var appDescription: String = ""
    var storeURL: String?
    var githubURL: String?
    var iconImageData: Data?
    var statusRaw: String = ProjectStatus.draft.serverValue

    /// Supabase `apps` テーブルへの同期成功時に保存される remote ID。
    /// nil = まだ同期していない (オフライン or 同期失敗)。
    /// 値あり = remote と紐付き済み。ProfileView の local 一覧から除外して remote 表示に切り替える。
    var remoteAppId: UUID?

    /// `apps.icon_url` (Supabase Storage public URL)。同期成功後に値が入る。
    /// ProfileView の local card がアイコン表示するときの fallback (ローカル iconImageData 優先)。
    var remoteIconUrl: String?

    init(
        name: String,
        platforms: [String] = [],
        techStack: [String] = [],
        category: SDCategory? = nil,
        appDescription: String = "",
        storeURL: String? = nil,
        githubURL: String? = nil,
        iconImageData: Data? = nil,
        status: ProjectStatus = .draft,
        remoteAppId: UUID? = nil,
        remoteIconUrl: String? = nil
    ) {
        self.name = name
        self.platforms = platforms
        self.techStack = techStack
        self.category = category
        self.createdAt = Date()
        self.appDescription = appDescription
        self.storeURL = storeURL
        self.githubURL = githubURL
        self.iconImageData = iconImageData
        self.statusRaw = status.serverValue
        self.remoteAppId = remoteAppId
        self.remoteIconUrl = remoteIconUrl
    }

    var status: ProjectStatus {
        get { ProjectStatus(serverValue: statusRaw) }
        set { statusRaw = newValue.serverValue }
    }
}

@Model
final class SDTimeEntry {
    // MARK: - Fields
    // 全プロパティに default 値 (lightweight migration 要件)。
    var startDate: Date = Date()
    var endDate: Date?
    var durationMinutes: Int = 0
    var projectName: String = ""
    var categoryName: String = ""
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
