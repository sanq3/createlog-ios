import Foundation
import SwiftData
import OSLog

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
    @ObservationIgnored
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "OnboardingViewModel")

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
        case reserved
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
            case .reserved: return "この handle は使用できません"
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

    // MARK: - UserDefaults persistence (2026-04-17)
    // onboarding 途中離脱 → 再起動で同じ step/入力値から再開する (Instagram/X 業界標準)。
    // `@State` だけだと app kill で消えるため UserDefaults に text 系を保存する。
    // image (avatar/icon) は Data が大きいので再選択してもらう。
    private enum DefaultsKey {
        static let currentStep = "onboarding.currentStep"
        static let isLoginMode = "onboarding.isLoginMode"
        static let selectedPlatforms = "onboarding.selectedPlatforms"
        static let selectedTechStack = "onboarding.selectedTechStack"
        static let projectName = "onboarding.projectName"
        static let displayName = "onboarding.displayName"
        static let bio = "onboarding.bio"
        static let handleInput = "onboarding.handleInput"
        static let roleTags = "onboarding.roleTags"
        static let appDescription = "onboarding.appDescription"
        static let storeURL = "onboarding.storeURL"
        static let githubURL = "onboarding.githubURL"
        static let releaseStatus = "onboarding.releaseStatus"
        // 2026-04-20: saving step で確定した SDProject 紐付け情報。
        // OAuth 後に root view identity が変化して viewModel が再生成されても、
        // localId (UUID) から SDProject を refetch して savedProjectID を復元できるようにする。
        static let savedProjectName = "onboarding.savedProjectName"
        static let savedPlatforms = "onboarding.savedPlatforms"
        static let isSaved = "onboarding.isSaved"
        static let savedProjectLocalId = "onboarding.savedProjectLocalId"
    }

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
        restoreFromDefaults()
        purgeUnconfirmedProjectsIfNeeded()
    }

    /// onboarding 未完了で残った SDProject を削除する。
    /// 案 D 以降 OnboardingViewModel は App init で常時生成されるため、毎回無条件に purge すると
    /// MainTab 利用中の既存 user の SDProject まで消してしまう。
    /// - onboardingCompleted=true → 既存 user の SDProject は触らない
    /// - currentStep != .welcome → 途中離脱からの再開なので saving で作った仮 SDProject は保持
    /// - それ以外 (初回起動や明示 reset) のみ既存 SDProject を clean
    private func purgeUnconfirmedProjectsIfNeeded() {
        if UserDefaults.standard.bool(forKey: "onboardingCompleted") { return }
        if currentStep != .welcome { return }
        let descriptor = FetchDescriptor<SDProject>()
        if let existing = try? modelContext.fetch(descriptor) {
            for project in existing { modelContext.delete(project) }
            try? modelContext.save()
        }
    }

    // MARK: - Persistence

    /// UserDefaults から onboarding state を復元する。
    /// app kill → relaunch 時に currentStep と text 入力値を取り戻して同じ step から再開できるようにする。
    private func restoreFromDefaults() {
        let d = UserDefaults.standard
        if let raw = d.object(forKey: DefaultsKey.currentStep) as? Int,
           let step = Step(rawValue: raw) {
            currentStep = step
        }
        isLoginMode = d.bool(forKey: DefaultsKey.isLoginMode)
        if let arr = d.array(forKey: DefaultsKey.selectedPlatforms) as? [String] {
            selectedPlatforms = Set(arr)
        }
        if let arr = d.array(forKey: DefaultsKey.selectedTechStack) as? [String] {
            selectedTechStack = Set(arr)
        }
        projectName = d.string(forKey: DefaultsKey.projectName) ?? ""
        displayName = d.string(forKey: DefaultsKey.displayName) ?? ""
        bio = d.string(forKey: DefaultsKey.bio) ?? ""
        handleInput = d.string(forKey: DefaultsKey.handleInput) ?? ""
        if let arr = d.array(forKey: DefaultsKey.roleTags) as? [String] {
            roleTags = Set(arr)
        }
        appDescription = d.string(forKey: DefaultsKey.appDescription) ?? ""
        storeURL = d.string(forKey: DefaultsKey.storeURL) ?? ""
        githubURL = d.string(forKey: DefaultsKey.githubURL) ?? ""
        if let raw = d.string(forKey: DefaultsKey.releaseStatus),
           let status = ProjectStatus(rawValue: raw) {
            releaseStatus = status
        }
        // 2026-04-20: saving step 以降の SDProject 紐付けを復元。
        // UserDefaults に残っている localId (UUID string) で SDProject を refetch する。
        savedProjectName = d.string(forKey: DefaultsKey.savedProjectName) ?? ""
        savedPlatforms = (d.array(forKey: DefaultsKey.savedPlatforms) as? [String]) ?? []
        isSaved = d.bool(forKey: DefaultsKey.isSaved)
        if isSaved,
           let uuidString = d.string(forKey: DefaultsKey.savedProjectLocalId),
           let localId = UUID(uuidString: uuidString) {
            let descriptor = FetchDescriptor<SDProject>(
                predicate: #Predicate<SDProject> { $0.localId == localId }
            )
            if let project = try? modelContext.fetch(descriptor).first {
                savedProjectID = project.persistentModelID
            } else {
                // SDProject が見つからない (ユーザが storage 掃除した / DB 破損) →
                // isSaved フラグも剥がして saving step からやり直させる (silent data loss 回避)
                isSaved = false
                savedProjectName = ""
                savedPlatforms = []
                d.removeObject(forKey: DefaultsKey.savedProjectLocalId)
                d.set(false, forKey: DefaultsKey.isSaved)
            }
        }
    }

    /// 現在の state を UserDefaults に保存する。
    /// advance/goBack/jump/backToWelcome など currentStep が変わる関数で呼ぶ。
    private func persist() {
        let d = UserDefaults.standard
        d.set(currentStep.rawValue, forKey: DefaultsKey.currentStep)
        d.set(isLoginMode, forKey: DefaultsKey.isLoginMode)
        d.set(Array(selectedPlatforms), forKey: DefaultsKey.selectedPlatforms)
        d.set(Array(selectedTechStack), forKey: DefaultsKey.selectedTechStack)
        d.set(projectName, forKey: DefaultsKey.projectName)
        d.set(displayName, forKey: DefaultsKey.displayName)
        d.set(bio, forKey: DefaultsKey.bio)
        d.set(handleInput, forKey: DefaultsKey.handleInput)
        d.set(Array(roleTags), forKey: DefaultsKey.roleTags)
        d.set(appDescription, forKey: DefaultsKey.appDescription)
        d.set(storeURL, forKey: DefaultsKey.storeURL)
        d.set(githubURL, forKey: DefaultsKey.githubURL)
        d.set(releaseStatus.rawValue, forKey: DefaultsKey.releaseStatus)
        // 2026-04-20: 紐付け再現用
        d.set(savedProjectName, forKey: DefaultsKey.savedProjectName)
        d.set(savedPlatforms, forKey: DefaultsKey.savedPlatforms)
        d.set(isSaved, forKey: DefaultsKey.isSaved)
        // savedProjectLocalId は performSave() で個別に書く (persistentModelID → UUID 取得不可のため)
    }

    /// onboarding 完走時に呼ぶ。UserDefaults の全 key を消して次 user のために clean。
    /// CreateLogApp の isPresented Binding の set closure から呼ぶ。
    func clearPersistedState() {
        let d = UserDefaults.standard
        let keys = [DefaultsKey.currentStep, DefaultsKey.isLoginMode,
                    DefaultsKey.selectedPlatforms, DefaultsKey.selectedTechStack,
                    DefaultsKey.projectName, DefaultsKey.displayName, DefaultsKey.bio,
                    DefaultsKey.handleInput, DefaultsKey.roleTags,
                    DefaultsKey.appDescription, DefaultsKey.storeURL, DefaultsKey.githubURL,
                    DefaultsKey.releaseStatus,
                    DefaultsKey.savedProjectName, DefaultsKey.savedPlatforms,
                    DefaultsKey.isSaved, DefaultsKey.savedProjectLocalId]
        for key in keys { d.removeObject(forKey: key) }
        // in-memory state も reset (次に OnboardingView 出た時に fresh)
        currentStep = .welcome
        isLoginMode = false
        selectedPlatforms = []
        selectedTechStack = []
        projectName = ""
        displayName = ""
        bio = ""
        handleInput = ""
        roleTags = []
        appDescription = ""
        storeURL = ""
        githubURL = ""
        releaseStatus = .draft
        savedProjectID = nil
        savedProjectName = ""
        savedPlatforms = []
        isSaved = false
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
        // welcome → appShowcase の瞬間は「新規ユーザーフロー開始」なので、
        // 過去に完了済みフラグが残っていても強制 reset して onboarding を in-progress にする。
        // これを怠ると OAuth 成功時点で root view が MainTabView に遷移してプロフィール設定 step が skip される。
        if currentStep == .welcome {
            UserDefaults.standard.set(false, forKey: "onboardingCompleted")
        }
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
        persist()
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
        persist()
    }

    /// 既存ユーザー用: Welcome から直接 accountPrompt へジャンプ。
    /// isLoginMode = true でタイトル・文言・リンクが切り替わる。
    func jumpToAccountPrompt() {
        isLoginMode = true
        currentStep = .accountPrompt
        persist()
    }

    /// ログイン画面から「初めての方はこちら」で Welcome に戻る。
    /// isLoginMode を false に戻して通常 onboarding を続行可能にする。
    func backToWelcome() {
        isLoginMode = false
        currentStep = .welcome
        persist()
    }

    // MARK: - Save (SDProject = マイプロダクト)

    /// saving step に入った瞬間に呼ばれる (アカウント作成前)。
    /// SDProject (name/platforms/techStack) のみローカル保存する。
    /// 詳細 (icon/URL/GitHub/description/status) はアカウント作成後に projectXxx step で逐次 update。
    ///
    /// 2026-04-20: OAuth 後 viewModel 再生成や app kill でも紐付けを失わないため、
    /// `project.localId` (UUID) を UserDefaults に保存する。restoreFromDefaults が refetch に使う。
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

        // OAuth / app kill 跨ぎの再紐付け用に UUID を UserDefaults へ。
        UserDefaults.standard.set(project.localId.uuidString, forKey: DefaultsKey.savedProjectLocalId)
        persist()
    }

    /// saving step で insert した SDProject を後から fetch して update する。
    ///
    /// 2026-04-20: silent data loss 対策。savedProjectID が万一 nil の場合は
    /// UserDefaults に残る localId から SDProject を再特定して復旧を試みる。
    /// それでも失敗する場合は os.Logger に error level で出して可視化
    /// (silent guard で呼び出し元が false success と誤認することを禁ず)。
    private func updateSavedProject(_ mutation: (SDProject) -> Void) {
        if savedProjectID == nil {
            recoverSavedProjectIDFromLocalId()
        }
        guard let id = savedProjectID,
              let project = modelContext.model(for: id) as? SDProject else {
            Self.logger.error("updateSavedProject: no SDProject to update (savedProjectID nil, recovery failed). currentStep=\(self.currentStep.rawValue)")
            return
        }
        mutation(project)
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("updateSavedProject: save failed: \(error.localizedDescription)")
        }
    }

    /// UserDefaults の `savedProjectLocalId` から SDProject を再 fetch して savedProjectID を張り直す。
    /// OnboardingView が再生成された後の defense-in-depth リカバリ
    /// (A: root-view identity 保持 / B: UserDefaults 永続化 の両輪で通常は不要、万一の保険)。
    private func recoverSavedProjectIDFromLocalId() {
        guard let uuidString = UserDefaults.standard.string(forKey: DefaultsKey.savedProjectLocalId),
              let localId = UUID(uuidString: uuidString) else { return }
        let descriptor = FetchDescriptor<SDProject>(
            predicate: #Predicate<SDProject> { $0.localId == localId }
        )
        if let project = try? modelContext.fetch(descriptor).first {
            savedProjectID = project.persistentModelID
            Self.logger.info("updateSavedProject: recovered savedProjectID via localId after in-memory loss")
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

    /// bio step (任意)。空入力なら server 呼出 skip (空 body の PATCH は PostgREST が弾く)。
    func saveBio() async -> Bool {
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return await updateProfilePartial(ProfileUpdateDTO(bio: trimmed))
    }

    /// roleTag step (任意、複数選択されても occupation に先頭のみ保存)。未選択なら server 呼出 skip。
    /// dot key (`onboarding.role.student` 等) は現在 locale の表示文字列 ("Student" / "学生") に
    /// 解決してから保存する。`profiles.occupation` は bio と同じく free text カラムとして扱い、
    /// 表示側で再 localize しない (ProfileEdit で自由編集する際の一貫性担保)。
    func saveRoleTag() async -> Bool {
        guard let firstKey = roleTags.sorted().first else { return true }
        let localized = NSLocalizedString(firstKey, comment: "")
        return await updateProfilePartial(ProfileUpdateDTO(occupation: localized))
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
    /// 4. 失敗時 silent fail ではなく os.Logger で warning 出力 (ローカル SDProject は残るので次回機会で retry)
    /// 既に同期済 (remoteAppId != nil) ならスキップ。完全に冪等。
    ///
    /// 2026-04-20: savedProjectID が nil の場合は UserDefaults 経由で localId 復旧を試みる。
    func syncProjectToRemote() async {
        guard let appRepository else {
            Self.logger.warning("syncProjectToRemote: appRepository unavailable, skipped")
            return
        }
        if savedProjectID == nil {
            recoverSavedProjectIDFromLocalId()
        }
        guard let id = savedProjectID else {
            Self.logger.error("syncProjectToRemote: savedProjectID nil even after recovery, skipped")
            return
        }
        guard let project = modelContext.model(for: id) as? SDProject else {
            Self.logger.error("syncProjectToRemote: SDProject not found for id, skipped")
            return
        }
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
            Self.logger.warning("syncProjectToRemote failed (best-effort, retry on next run): \(error.localizedDescription)")
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
    /// - `HandleValidator` の reserved list に含まれない (canonical `ReservedHandles.json`)
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
        if HandleValidator.isReserved(trimmed) { return .reserved }
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
