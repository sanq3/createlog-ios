import Foundation
import SwiftData

/// オンボーディングの 6 画面フローを駆動する状態ホルダ。
/// 起動時動画スプラッシュ (SplashView) が世界観を提示するため、wordmark step は不要。
/// Linear 流の hands-on learning を採用: step 02-05 で本物の入力を受け取り、
/// step 05 で実際に SwiftData へ 1 件の SDTimeEntry を保存する。
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case tagline = 0      // 01 「作ったことを、残していく。」
        case projectName = 1  // 02 何を作ってる？
        case duration = 2     // 03 今日、どれだけやった？
        case tag = 3          // 04 どんな作業だった？
        case saving = 4       // 05 保存中 → 保存した
        case welcome = 5      // 06 ようこそ
    }

    /// タグ候補 (標準カテゴリから抜粋、記号ゼロ)
    static let tagOptions = ["開発", "デザイン", "学習", "設計", "ミーティング", "調査", "ライティング"]

    // MARK: - State

    var currentStep: Step = .tagline
    var projectName: String = ""
    var durationHours: Int = 0
    var durationMinutes: Int = 30
    var selectedTag: String? = nil
    var isSaved: Bool = false
    var savedProjectName: String = ""
    var savedDurationMinutes: Int = 0
    var savedCategoryName: String = ""

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

    /// step 06 に入った瞬間に呼ばれる。実際に SwiftData に 1 件挿入する。
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
