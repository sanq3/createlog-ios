import Foundation

@MainActor @Observable
final class ProfileEditViewModel {

    // MARK: - Dependencies

    @ObservationIgnored private let profileRepository: any ProfileRepositoryProtocol
    /// save 成功時に `.profileUpdated` を publish し、Feed / Notifications / PostDetail / UserProfile
    /// 等で保持する投稿者情報 (name / handle / avatarUrl) を client 側で即時 patch する。
    /// server-side trigger (migration) による非正規化 column の propagation を待たず UX を向上させる。
    @ObservationIgnored private let eventBus: DomainEventBus?
    /// save 成功時に `currentProfile` を更新し、全 VM が最新 profile を参照できるようにする。
    @ObservationIgnored private let domainContext: DomainContext?

    // MARK: - Editable State

    var displayName: String
    var handle: String
    var bio: String
    var occupation: String
    var experienceLevel: ExperienceLevel
    var links: [EditableLink]
    var skills: [String]
    var newSkill: String = ""
    var interests: Set<String>

    // MARK: - Save State

    var isSaving: Bool = false
    var errorMessage: String?
    /// 保存成功フラグ。View はこれを監視して dismiss する。
    var didSaveSuccessfully: Bool = false

    /// PhotosPicker で選択されたアバター画像の生バイナリ。
    /// save() 時に Supabase Storage にアップロードされ、profile.avatarUrl に反映される。
    /// nil のままなら avatar 変更なし。
    var pendingAvatarData: Data?

    /// 既存の avatar URL (init 時の User.avatarUrl)。PhotosPicker で新規選択前のフォールバック表示用。
    let currentAvatarUrl: String?

    // MARK: - Originals (for change detection)

    @ObservationIgnored private let originalName: String
    @ObservationIgnored private let originalHandle: String
    @ObservationIgnored private let originalBio: String
    @ObservationIgnored private let originalOccupation: String
    @ObservationIgnored private let originalExperience: ExperienceLevel
    @ObservationIgnored private let originalLinks: [EditableLink]
    @ObservationIgnored private let originalSkills: [String]
    @ObservationIgnored private let originalInterests: Set<String>

    // MARK: - Computed

    var hasChanges: Bool {
        displayName != originalName
            || handle != originalHandle
            || bio != originalBio
            || occupation != originalOccupation
            || experienceLevel != originalExperience
            || links != originalLinks
            || skills != originalSkills
            || interests != originalInterests
            || pendingAvatarData != nil
    }

    var isHandleValid: Bool {
        let pattern = /^[a-zA-Z0-9_]{3,15}$/
        guard handle.wholeMatch(of: pattern) != nil else { return false }
        // canonical ReservedHandles.json と照合 (`docs/reserved-handles.md` 参照)
        return !HandleValidator.isReserved(handle)
    }

    var canSave: Bool {
        hasChanges && isHandleValid && !isSaving
    }

    static let interestOptions = [
        "iOS", "Android", "Web", "バックエンド", "インフラ",
        "AI/ML", "ゲーム", "デザイン", "個人開発", "OSS",
        "セキュリティ", "データ", "モバイル", "クラウド", "DevOps",
    ]

    // MARK: - Init

    init(
        user: User,
        profileRepository: any ProfileRepositoryProtocol = NoOpProfileRepository(),
        eventBus: DomainEventBus? = nil,
        domainContext: DomainContext? = nil
    ) {
        self.profileRepository = profileRepository
        self.eventBus = eventBus
        self.domainContext = domainContext

        displayName = user.name
        handle = user.handle
        bio = user.bio
        occupation = user.occupation
        experienceLevel = user.experienceLevel
        links = user.links.map { EditableLink(url: $0.url) }
        skills = user.skills
        interests = Set(user.interests)
        currentAvatarUrl = user.avatarUrl

        originalName = user.name
        originalHandle = user.handle
        originalBio = user.bio
        originalOccupation = user.occupation
        originalExperience = user.experienceLevel
        originalLinks = user.links.map { EditableLink(url: $0.url) }
        originalSkills = user.skills
        originalInterests = Set(user.interests)
    }

    // MARK: - Save

    /// 編集内容を Supabase に保存する。
    /// サーバー粒度に合わせてサブセット (handle/displayName/bio/occupation/experienceYears) のみ更新する。
    /// links/skills/interests はサーバースキーマ未対応のためここでは送信しない。
    func save() async {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        // ハンドル変更時は衝突チェック
        if handle != originalHandle {
            do {
                let available = try await profileRepository.checkHandleAvailability(handle)
                guard available else {
                    errorMessage = String(localized: "auth.handle.taken")
                    return
                }
            } catch {
                errorMessage = String(localized: "auth.error.handleCheck")
                return
            }
        }

        // 先に avatar を Supabase Storage にアップロードして URL を取得する
        var avatarUrlString: String?
        if let data = pendingAvatarData {
            do {
                let url = try await profileRepository.uploadAvatar(imageData: data, contentType: "image/jpeg")
                avatarUrlString = url.absoluteString
            } catch {
                errorMessage = String(localized: "profile.error.avatarUpload")
                return
            }
        }

        let updates = ProfileUpdateDTO(
            handle: handle,
            displayName: displayName.isEmpty ? nil : displayName,
            avatarUrl: avatarUrlString,
            ageGroup: nil,
            gender: nil,
            occupation: occupation.isEmpty ? nil : occupation,
            workType: nil,
            incomeStatus: nil,
            experienceYears: experienceLevel.serverValue,
            bio: bio.isEmpty ? nil : bio,
            notificationEnabled: nil,
            onboardingCompleted: nil
        )

        do {
            let updatedDTO = try await profileRepository.updateProfile(updates)
            // 2026-04-20 Phase 3: denormalize 伝播。client 側で即時に全 VM に broadcast し、
            // Feed / Notifications / PostDetail / UserProfile 等の author 表示を patch させる。
            // server-side trigger (migration) による posts.author_*/notifications.actor_* 更新と
            // 二層防御: trigger 成立前でも UI は即反映される。
            let updatedUser = User(from: updatedDTO)
            domainContext?.currentProfile = updatedUser
            eventBus?.publish(.profileUpdated(
                userId: updatedDTO.id,
                displayName: updatedUser.name,
                handle: updatedUser.handle,
                avatarUrl: updatedUser.avatarUrl,
                bio: updatedUser.bio
            ))
            didSaveSuccessfully = true
        } catch {
            errorMessage = String(localized: "profile.error.save")
        }
    }

    // MARK: - Actions

    func addSkill() {
        let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !skills.contains(trimmed) else { return }
        skills.append(trimmed)
        newSkill = ""
        HapticManager.light()
    }

    func removeSkill(_ skill: String) {
        skills.removeAll { $0 == skill }
        HapticManager.light()
    }

    func toggleInterest(_ interest: String) {
        if interests.contains(interest) {
            interests.remove(interest)
        } else {
            interests.insert(interest)
        }
        HapticManager.selection()
    }

    func addLink() {
        links.append(EditableLink(url: ""))
        HapticManager.light()
    }

    func removeLink(_ link: EditableLink) {
        links.removeAll { $0.id == link.id }
        HapticManager.light()
    }
}

// MARK: - Supporting Types

struct EditableLink: Identifiable, Equatable {
    let id: UUID
    let url: String

    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }
}
