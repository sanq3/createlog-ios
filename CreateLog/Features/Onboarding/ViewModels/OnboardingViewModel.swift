import Foundation
import SwiftData

/// オンボーディング 8 画面フロー。マイプロダクト (SDProject) 登録が主目的。
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName → saving → accountPrompt
@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome = 0
        case appShowcase = 1
        case tutorialIntro = 2
        case platform = 3
        case techStack = 4
        case projectName = 5
        case saving = 6
        case accountPrompt = 7
    }

    // MARK: - State

    var currentStep: Step = .welcome

    // Product registration (マイプロダクト)
    var selectedPlatforms: Set<String> = []
    var selectedTechStack: Set<String> = []
    var projectName: String = ""
    var isSaved: Bool = false
    var savedProjectName: String = ""
    var savedPlatforms: [String] = []

    @ObservationIgnored private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Derived

    var canAdvanceFromProjectName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Navigation

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    // MARK: - Save (SDProject = マイプロダクト)

    /// saving step に入った瞬間に呼ばれる。
    /// SDProject をローカル (SwiftData) に保存。
    /// プロフィールのマイプロダクト + 記録タブのプロジェクト選択に反映される。
    func performSave() {
        guard !isSaved else { return }

        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "My Project" : trimmedName
        let platforms = Array(selectedPlatforms)
        let techStack = Array(selectedTechStack)

        let project = SDProject(name: finalName, platforms: platforms, techStack: techStack)
        modelContext.insert(project)
        try? modelContext.save()

        savedProjectName = finalName
        savedPlatforms = platforms
        isSaved = true
    }
}
