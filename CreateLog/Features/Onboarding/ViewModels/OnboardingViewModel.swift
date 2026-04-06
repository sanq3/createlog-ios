import Foundation
import SwiftData

/// オンボーディングの 8 画面フローを駆動する状態ホルダ。
/// welcome → appShowcase → 選択式 (tag/duration) → projectName(唯一のテキスト入力) → saving → accountPrompt → profileSetup
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome = 0        // ようこそ、CreateLog へ。
        case appShowcase = 1    // アプリ機能プレビュー (実在機能のみ)
        case tag = 2            // どんな作業？ (選択式)
        case duration = 3       // どれくらいやった？ (ピッカー)
        case projectName = 4    // プロダクト名 (唯一のテキスト入力)
        case saving = 5         // 保存演出
        case accountPrompt = 6  // アカウント作成促進
        case profileSetup = 7   // プロフィール設定
    }

    /// タグ候補 (標準カテゴリから抜粋)
    static let tagOptions = ["開発", "デザイン", "学習", "設計", "ミーティング", "調査", "ライティング"]

    /// 興味分野候補
    static let interestOptions = ["iOS", "Android", "Web Frontend", "Backend", "AI / ML", "DevOps", "Game Dev", "Design"]

    // MARK: - State

    var currentStep: Step = .welcome
    var projectName: String = ""
    var durationHours: Int = 0
    var durationMinutes: Int = 30
    var selectedTag: String? = nil
    var isSaved: Bool = false
    var savedProjectName: String = ""
    var savedDurationMinutes: Int = 0
    var savedCategoryName: String = ""

    // Profile (ローカル保持、Auth 実装後にサーバー同期)
    var displayName: String = ""
    var selectedInterests: Set<String> = []

    @ObservationIgnored private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Derived

    var totalMinutes: Int {
        max(0, durationHours * 60 + durationMinutes)
    }

    var canAdvanceFromProjectName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Navigation

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    // MARK: - Save

    /// saving step に入った瞬間に呼ばれる。SwiftData に 1 件挿入。
    func performSave() {
        guard !isSaved else { return }

        let minutes = max(1, totalMinutes)
        let end = Date()
        let start = end.addingTimeInterval(-Double(minutes * 60))
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "最初の記録" : trimmedName
        let category = selectedTag ?? "開発"

        let entry = SDTimeEntry(
            startDate: start,
            endDate: end,
            durationMinutes: minutes,
            projectName: finalName,
            categoryName: category,
            memo: nil
        )
        modelContext.insert(entry)
        try? modelContext.save()

        savedProjectName = finalName
        savedDurationMinutes = minutes
        savedCategoryName = category
        isSaved = true
    }
}
