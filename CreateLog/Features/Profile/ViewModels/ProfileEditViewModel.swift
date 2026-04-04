import Foundation

@MainActor @Observable
final class ProfileEditViewModel {

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
    }

    var isHandleValid: Bool {
        let pattern = /^[a-zA-Z0-9_]{3,15}$/
        return handle.wholeMatch(of: pattern) != nil
    }

    var canSave: Bool {
        hasChanges && isHandleValid
    }

    static let interestOptions = [
        "iOS", "Android", "Web", "バックエンド", "インフラ",
        "AI/ML", "ゲーム", "デザイン", "個人開発", "OSS",
        "セキュリティ", "データ", "モバイル", "クラウド", "DevOps",
    ]

    // MARK: - Init

    init(user: User) {
        displayName = user.name
        handle = user.handle
        bio = user.bio
        occupation = user.occupation
        experienceLevel = user.experienceLevel
        links = user.links.map { EditableLink(url: $0.url) }
        skills = user.skills
        interests = Set(user.interests)

        originalName = user.name
        originalHandle = user.handle
        originalBio = user.bio
        originalOccupation = user.occupation
        originalExperience = user.experienceLevel
        originalLinks = user.links.map { EditableLink(url: $0.url) }
        originalSkills = user.skills
        originalInterests = Set(user.interests)
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
