import Foundation
import SwiftData

/// オンボーディング 20 画面フロー (2026-04-14 再設計、1 画面 1 質問粒度)。
/// 前半 (accountPrompt 含む 9 step) はアカウント作成前、後半 11 step は作成後に下部
/// preview card (profile / product) を出しながら逐次保存する。
/// welcome → appShowcase → tutorialIntro → platform → techStack → projectName →
/// saving → accountPrompt → signInCelebration → displayName → handleSetup →
/// avatar → bio → roleTag → projectIcon → projectURL → projectGitHub →
/// projectDescription → projectStatus → completionCelebration
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
        case signInCelebration = 8
        case displayName = 9
        case handleSetup = 10
        case avatar = 11
        case bio = 12
        case roleTag = 13
        case projectIcon = 14
        case projectURL = 15
        case projectGitHub = 16
        case projectDescription = 17
        case projectStatus = 18
        case completionCelebration = 19

        /// 下部 preview card を出すかどうか (アカウント作成後のフローのみ)
        var showsPreviewCard: Bool {
            rawValue >= Step.displayName.rawValue && rawValue <= Step.projectStatus.rawValue
        }

        /// preview card の種類 (profile 系 / product 系)
        enum PreviewKind { case profile, product, none }
        var previewKind: PreviewKind {
            switch self {
            case .displayName, .handleSetup, .avatar, .bio, .roleTag: .profile
            case .projectIcon, .projectURL, .projectGitHub, .projectDescription, .projectStatus: .product
            default: .none
            }
        }

        /// 任意 step (「あとで設定する」を出す)
        var isOptional: Bool {
            switch self {
            case .avatar, .bio, .roleTag, .projectIcon, .projectURL, .projectGitHub, .projectDescription, .projectStatus: true
            default: false
            }
        }
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

    /// Welcome 画面のログインリンクから accountPrompt へジャンプしたか。
    /// true の間は AccountPrompt のタイトル・文言・プロジェクトカードがログイン用に切り替わる。
    var isLoginMode: Bool = false

    // Product registration (マイプロダクト)
    var selectedPlatforms: Set<String> = []
    var selectedTechStack: Set<String> = []
    var projectName: String = ""
    var isSaved: Bool = false
    var savedProjectName: String = ""
    var savedPlatforms: [String] = []
    /// saving step で insert した SDProject の ID。後続の project* step で update 対象。
    var savedProjectID: PersistentIdentifier? = nil

    // Project detail (2026-04-14, projectDetail step)
    var appDescription: String = ""
    var storeURL: String = ""
    var githubURL: String = ""
    var iconImageData: Data? = nil
    var releaseStatus: ProjectStatus = .draft

    // Profile setup (2026-04-14, profileSetup step)
    var displayName: String = ""
    var bio: String = ""
    var avatarImageData: Data? = nil
    var roleTags: Set<String> = []
    var isSavingProfile: Bool = false
    var profileSaveError: String? = nil

    // Handle setup (T6)
    var handleInput: String = ""
    var handleValidation: HandleValidation = .empty
    var handleAvailability: HandleAvailability = .unknown
    var isConfirmingHandle: Bool = false
    var handleConfirmError: String?

    @ObservationIgnored private let modelContext: ModelContext
    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    @ObservationIgnored private let appRepository: (any AppRepositoryProtocol)?
    @ObservationIgnored private let authService: (any AuthServiceProtocol)?
    @ObservationIgnored private var availabilityCheckTask: Task<Void, Never>?

    init(
        modelContext: ModelContext,
        profileRepository: any ProfileRepositoryProtocol,
        appRepository: (any AppRepositoryProtocol)? = nil,
        authService: (any AuthServiceProtocol)? = nil
    ) {
        self.modelContext = modelContext
        self.profileRepository = profileRepository
        self.appRepository = appRepository
        self.authService = authService
        purgeUnconfirmedProjects()
    }

    /// onboarding 未完了で残った SDProject を全削除する。
    /// OnboardingView が出る = `onboardingCompleted == false` (CreateLogApp で分岐済) なので、
    /// 残存分は「前回 onboarding 途中離脱の仮データ」と判断できる。
    /// アカウント作成まで到達しなければ毎回リセットし、マイサービスが無限に積み上がるのを防ぐ。
    private func purgeUnconfirmedProjects() {
        let descriptor = FetchDescriptor<SDProject>()
        if let existing = try? modelContext.fetch(descriptor) {
            for project in existing {
                modelContext.delete(project)
            }
            try? modelContext.save()
        }
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

    /// edge swipe で戻れる step か。
    /// 戻れるのは「入力/選択 step → 直前の入力/選択 step」のみ。
    /// 情報表示 / 自動遷移 / 認証ゲート / 演出 / 跨ぎ境界は戻せない。
    var canGoBack: Bool {
        switch currentStep {
        case .techStack, .projectName,
             .handleSetup, .avatar, .bio, .roleTag,
             .projectIcon, .projectURL, .projectGitHub, .projectDescription, .projectStatus:
            return true
        default:
            return false
        }
    }

    /// 直前の入力/選択 step に戻る。canGoBack を満たさない場合は no-op。
    /// 遷移ルール: rawValue - 1 で隣接 step に戻るだけ。戻り許可 whiteList が遷移境界を保証する。
    func goBack() {
        guard canGoBack, let prev = Step(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    /// 既存ユーザー用: Welcome から直接 accountPrompt へジャンプ。
    /// isLoginMode = true でタイトル・文言・リンクが切り替わる。
    func jumpToAccountPrompt() {
        isLoginMode = true
        currentStep = .accountPrompt
    }

    /// ログイン画面から「初めての方はこちら」で Welcome に戻る。
    /// isLoginMode を false に戻して通常 onboarding を続行可能にする。
    func backToWelcome() {
        isLoginMode = false
        currentStep = .welcome
    }

    // MARK: - Save (SDProject = マイプロダクト)

    /// saving step に入った瞬間に呼ばれる (アカウント作成前)。
    /// SDProject (name/platforms/techStack) のみローカル保存する。
    /// 詳細 (icon/URL/GitHub/description/status) はアカウント作成後に projectXxx step で逐次 update。
    func performSave() {
        guard !isSaved else { return }

        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? "My Project" : trimmedName
        let platforms = Array(selectedPlatforms)
        let techStack = Array(selectedTechStack)

        let project = SDProject(
            name: finalName,
            platforms: platforms,
            techStack: techStack
        )
        modelContext.insert(project)
        try? modelContext.save()

        savedProjectID = project.persistentModelID
        savedProjectName = finalName
        savedPlatforms = platforms
        isSaved = true
    }

    /// saving step で insert した SDProject を後から fetch して update する。
    private func updateSavedProject(_ mutation: (SDProject) -> Void) {
        guard let id = savedProjectID else { return }
        if let project = modelContext.model(for: id) as? SDProject {
            mutation(project)
            try? modelContext.save()
        }
    }

    // MARK: - Per-step Profile save (2026-04-14, 1 画面 1 質問)

    /// displayName step (必須)。
    func saveDisplayName() async -> Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return await updateProfilePartial(
            ProfileUpdateDTO(displayName: trimmed)
        )
    }

    /// avatar step (任意、画像なしでスキップ可)。
    /// Storage upload → profiles.avatar_url を update。
    func saveAvatar() async -> Bool {
        guard let imageData = avatarImageData else { return true }
        isSavingProfile = true
        profileSaveError = nil
        defer { isSavingProfile = false }

        do {
            let url = try await profileRepository.uploadAvatar(imageData: imageData, contentType: "image/jpeg")
            _ = try await profileRepository.updateProfile(ProfileUpdateDTO(avatarUrl: url.absoluteString))
            return true
        } catch {
            profileSaveError = error.localizedDescription
            return false
        }
    }

    /// bio step (任意)。
    func saveBio() async -> Bool {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return await updateProfilePartial(
            ProfileUpdateDTO(bio: trimmed.isEmpty ? nil : trimmed)
        )
    }

    /// roleTag step (任意、複数選択されても occupation に先頭のみ保存)。
    func saveRoleTag() async -> Bool {
        let first = roleTags.sorted().first
        return await updateProfilePartial(
            ProfileUpdateDTO(occupation: first)
        )
    }

    /// 共通の部分更新ヘルパ。
    private func updateProfilePartial(_ updates: ProfileUpdateDTO) async -> Bool {
        isSavingProfile = true
        profileSaveError = nil
        defer { isSavingProfile = false }

        do {
            _ = try await profileRepository.updateProfile(updates)
            return true
        } catch {
            profileSaveError = error.localizedDescription
            return false
        }
    }

    // MARK: - Per-step Project save (2026-04-14)

    /// projectIcon step (任意)。iconImageData を SDProject に反映。
    func saveProjectIcon() {
        updateSavedProject { $0.iconImageData = iconImageData }
    }

    /// projectURL step (任意)。空なら nil で保存。
    func saveProjectURL() {
        let trimmed = storeURL.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSavedProject { $0.storeURL = trimmed.isEmpty ? nil : trimmed }
    }

    /// projectGitHub step (任意)。
    func saveProjectGitHub() {
        let trimmed = githubURL.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSavedProject { $0.githubURL = trimmed.isEmpty ? nil : trimmed }
    }

    /// projectDescription step (任意)。
    func saveProjectDescription() {
        let trimmed = appDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        updateSavedProject { $0.appDescription = trimmed }
    }

    /// projectStatus step (任意)。
    func saveProjectStatus() {
        updateSavedProject { $0.status = releaseStatus }
    }

    // MARK: - Remote sync (projectStatus → completionCelebration の境界で実行)

    /// 完成した SDProject を Supabase `apps` テーブルに upsert する。
    /// 1. icon があれば Storage upload → URL 取得
    /// 2. AppInsertDTO 構築して insertApp
    /// 3. 成功時 SDProject.remoteAppId / remoteIconUrl を保存 (ProfileView の重複表示防止)
    /// 4. 失敗時 silent fail (ローカル SDProject は残るので次回機会で retry)
    /// 既に同期済 (remoteAppId != nil) ならスキップ。完全に冪等。
    func syncProjectToRemote() async {
        guard let appRepository else { return }
        guard let id = savedProjectID else { return }
        guard let project = modelContext.model(for: id) as? SDProject else { return }
        guard project.remoteAppId == nil else { return }

        let snapshot = ProjectSyncSnapshot(from: project)

        do {
            var iconURLString: String?
            if let iconData = snapshot.iconImageData {
                let url = try await appRepository.uploadAppIcon(
                    imageData: iconData,
                    contentType: "image/jpeg"
                )
                iconURLString = url.absoluteString
            }

            let insertDTO = AppInsertDTO(
                name: snapshot.name,
                description: snapshot.appDescription.isEmpty ? nil : snapshot.appDescription,
                iconUrl: iconURLString,
                screenshots: nil,
                platform: snapshot.primaryPlatform,
                appUrl: nil,
                storeUrl: snapshot.storeURL,
                githubUrl: snapshot.githubURL,
                status: snapshot.statusRaw,
                category: nil
            )

            let inserted = try await appRepository.insertApp(insertDTO)

            await MainActor.run {
                if let liveProject = modelContext.model(for: id) as? SDProject {
                    liveProject.remoteAppId = inserted.id
                    liveProject.remoteIconUrl = iconURLString
                    try? modelContext.save()
                }
            }
        } catch {
            print("[OnboardingViewModel] ❌ syncProjectToRemote failed: \(error.localizedDescription)")
        }
    }

    /// SDProject のスナップショット (Sendable 化 — actor hop で SDProject を直接渡せないため)
    private struct ProjectSyncSnapshot: Sendable {
        let name: String
        let appDescription: String
        let storeURL: String?
        let githubURL: String?
        let iconImageData: Data?
        let statusRaw: String
        let primaryPlatform: String

        init(from project: SDProject) {
            self.name = project.name
            self.appDescription = project.appDescription
            self.storeURL = project.storeURL
            self.githubURL = project.githubURL
            self.iconImageData = project.iconImageData
            self.statusRaw = project.statusRaw
            self.primaryPlatform = Self.serverValueForPlatform(project.platforms.first)
        }

        /// SDProject.platforms (例 "iOS") を apps.platform serverValue ("ios") に正規化。
        private static func serverValueForPlatform(_ raw: String?) -> String {
            switch (raw ?? "").lowercased() {
            case "ios": return "ios"
            case "android": return "android"
            case "web": return "web"
            default: return "other"
            }
        }
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
