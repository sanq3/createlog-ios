import Foundation
import SwiftData

/// オンボーディング 9 画面フロー。マイプロダクト (SDProject) 登録 + ハンドル選択が主目的。
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName → saving → accountPrompt → handleSetup
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
        case handleSetup = 8
    }

    // MARK: - Handle validation (T6)

    /// ハンドル形式バリデーションの結果
    enum HandleValidation: Equatable {
        case empty
        case tooShort
        case tooLong
        case mustStartWithLetter
        case invalidCharacters
        case valid

        var isValid: Bool { self == .valid }

        /// UI に出すエラーメッセージ (empty/valid は nil)
        var errorMessage: String? {
            switch self {
            case .empty, .valid: return nil
            case .tooShort: return "3文字以上必要です"
            case .tooLong: return "15文字以下にしてください"
            case .mustStartWithLetter: return "先頭は英字で始めてください"
            case .invalidCharacters: return "英数字とアンダースコア (_) のみ使えます"
            }
        }
    }

    /// ハンドル一意性チェックの結果
    enum HandleAvailability: Equatable {
        case unknown
        case checking
        case available
        case taken
        case error(String)
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

    // Handle setup (T6)
    var handleInput: String = ""
    var handleValidation: HandleValidation = .empty
    var handleAvailability: HandleAvailability = .unknown
    var isConfirmingHandle: Bool = false
    var handleConfirmError: String?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private var availabilityCheckTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        profileRepository: any ProfileRepositoryProtocol
    ) {
        self.modelContext = modelContext
        self.profileRepository = profileRepository
    }

    // MARK: - Derived

    var canAdvanceFromProjectName: Bool {
        !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// ハンドル確定ボタンの activation 条件:
    /// - 形式 valid
    /// - 一意性 available
    /// - 確定処理中でない
    var canConfirmHandle: Bool {
        handleValidation.isValid && handleAvailability == .available && !isConfirmingHandle
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

    // MARK: - Handle input (T6)

    /// 静的バリデータ。
    /// - 3-15 文字
    /// - 先頭は英字 (`a-zA-Z`)
    /// - 2 文字目以降は英数字とアンダースコア
    static func validateHandle(_ raw: String) -> HandleValidation {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .empty }
        if trimmed.count < 3 { return .tooShort }
        if trimmed.count > 15 { return .tooLong }
        guard let first = trimmed.first, first.isLetter, first.isASCII else { return .mustStartWithLetter }
        let allowedSet = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: "_"))
        let scalars = trimmed.unicodeScalars
        for scalar in scalars {
            guard scalar.isASCII, allowedSet.contains(scalar) else { return .invalidCharacters }
        }
        return .valid
    }

    /// TextField の onChange で呼ぶ。
    /// - validation を即時反映
    /// - valid なら 500ms debounce で availability check を kick
    /// - invalid or 空なら既存 availability check は cancel
    func onHandleInputChanged(_ newValue: String) {
        handleInput = newValue
        handleConfirmError = nil
        handleValidation = Self.validateHandle(newValue)

        availabilityCheckTask?.cancel()

        guard handleValidation.isValid else {
            handleAvailability = .unknown
            return
        }

        handleAvailability = .checking

        availabilityCheckTask = Task { [weak self, profileRepository] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            guard let self else { return }

            // Race defense 1 段目: debounce 中に input が変わっていたら skip
            let snapshot = await MainActor.run { self.handleInput }
            guard snapshot == newValue else { return }

            do {
                let available = try await profileRepository.checkHandleAvailability(newValue)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    // Race defense 2 段目: await 中に input が変わっていたら skip
                    guard self.handleInput == newValue else { return }
                    self.handleAvailability = available ? .available : .taken
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.handleInput == newValue else { return }
                    self.handleAvailability = .error(error.localizedDescription)
                }
            }
        }
    }

    /// ハンドル確定ボタン。
    /// - ProfileUpdateDTO(handle:) で remote に書き込み
    /// - 成功時: onSuccess を呼ぶ (View 側で dismiss など)
    /// - 失敗時: handleConfirmError にセット
    func confirmHandle() async -> Bool {
        guard canConfirmHandle else { return false }

        let handle = handleInput.trimmingCharacters(in: .whitespaces)
        isConfirmingHandle = true
        handleConfirmError = nil

        defer { isConfirmingHandle = false }

        do {
            let updates = ProfileUpdateDTO(handle: handle)
            _ = try await profileRepository.updateProfile(updates)
            return true
        } catch {
            handleConfirmError = error.localizedDescription
            return false
        }
    }
}
