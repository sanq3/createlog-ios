import Foundation
import SwiftData

/// Offline-first Decorator for `ProfileRepositoryProtocol`。
///
/// ## 目的
/// プロフィール画面を開いた瞬間の "一瞬の空表示 (flicker)" を消す。
/// 業界標準 (Instagram cache-first / Bluesky placeholderData / Threads cached profile precache) の iOS 版。
///
/// ## 戦略 (SWR + Cache-first rendering)
/// - **Synchronous cache read (`cachedMyProfile` / `cachedProfile(userId:)`)**:
///   View の init 内で同期 fetch し、profile プロパティの初期値として使う。cold cache は nil。
///   自分の profile は `UserDefaults(cl.lastKnownMyProfileId)` に cache 書き込み時の PK を記録して識別。
///   Keychain 不要 (profile.id は機密ではない、単なる PK)。
///
/// - **Read (fetchMyProfile / fetchProfile)**:
///   1. remote fetch を試行
///   2. 成功 → `SDProfileCache` upsert、`UserDefaults` に自分の ID を記録、remote を return
///   3. 失敗 (network 不可 等) → `SDProfileCache` から fallback 返却
///
/// - **Write (updateProfile)**:
///   1. remote 試行 → 成功 → cache upsert + return
///   2. remote 失敗 → throw (MVP scope: offline profile edit の enqueue は v1.1 で。
///      profile 編集は頻度が低く offline 必須度が低いため)
///
/// - **passthrough**: `checkHandleAvailability` / `uploadAvatar` は cache 関係なし、underlying へ委譲
///
/// ## 注意
/// - ModelContainer 未注入時 (preview / 未初期化) は underlying のみ使用、cache 無効
/// - ProfileDTO は `init(from: Decoder)` のみ持つため SDProfileCache → ProfileDTO は JSON round-trip
///   (既存 `SDPostCache.toDTO()` と同型)
final class OfflineFirstProfileRepository: ProfileRepositoryProtocol, @unchecked Sendable {
    private let underlying: any ProfileRepositoryProtocol
    private let modelContainer: ModelContainer?

    /// 自分の profile PK を永続化する UserDefaults key。
    /// Keychain 不要 (profile.id は DB PK、auth secret ではない)。
    private static let lastKnownMyProfileIdKey = "cl.lastKnownMyProfileId"

    init(
        underlying: any ProfileRepositoryProtocol,
        modelContainer: ModelContainer?
    ) {
        self.underlying = underlying
        self.modelContainer = modelContainer
    }

    // MARK: - Read (remote-first with cache fallback)

    func fetchMyProfile() async throws -> ProfileDTO {
        do {
            let remote = try await underlying.fetchMyProfile()
            upsertCache(remote)
            UserDefaults.standard.set(remote.id.uuidString, forKey: Self.lastKnownMyProfileIdKey)
            return remote
        } catch {
            if let cached = readFromCacheMyProfile() {
                return cached
            }
            throw error
        }
    }

    func fetchProfile(userId: UUID) async throws -> ProfileDTO {
        do {
            let remote = try await underlying.fetchProfile(userId: userId)
            upsertCache(remote)
            return remote
        } catch {
            if let cached = readFromCache(userId: userId) {
                return cached
            }
            throw error
        }
    }

    // MARK: - Write (remote-first, cache upsert on success)

    func updateProfile(_ updates: ProfileUpdateDTO) async throws -> ProfileDTO {
        let remote = try await underlying.updateProfile(updates)
        upsertCache(remote)
        UserDefaults.standard.set(remote.id.uuidString, forKey: Self.lastKnownMyProfileIdKey)
        return remote
    }

    // MARK: - Passthrough (cache 非対象)

    func checkHandleAvailability(_ handle: String) async throws -> Bool {
        try await underlying.checkHandleAvailability(handle)
    }

    func uploadAvatar(imageData: Data, contentType: String) async throws -> URL {
        try await underlying.uploadAvatar(imageData: imageData, contentType: contentType)
    }

    // MARK: - SWR cache reads (synchronous)

    func cachedMyProfile() -> ProfileDTO? {
        guard let idString = UserDefaults.standard.string(forKey: Self.lastKnownMyProfileIdKey),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return readFromCache(userId: id)
    }

    func cachedProfile(userId: UUID) -> ProfileDTO? {
        readFromCache(userId: userId)
    }

    // MARK: - Feed precache (Bluesky pattern)

    /// Feed / Comment / Notification 取得時に得られた author 3 フィールドを cache に先行書き込み。
    /// - 既存 row あり: handle/displayName/avatarUrl のみ上書き。他 field (bio/counts/links 等) は保持
    /// - 既存 row なし: minimal row を insert (email は空、counts は 0 等)。fetchProfile が後に来れば全上書き
    /// - all-nil 呼び出しは no-op (feed の author JOIN が失敗した場合)
    func precacheBasic(userId: UUID, handle: String?, displayName: String?, avatarUrl: String?) {
        guard handle != nil || displayName != nil || avatarUrl != nil else { return }
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDProfileCache>(
            predicate: #Predicate { $0.remoteId == userId }
        )
        if let existing = try? context.fetch(descriptor).first {
            if let handle { existing.handle = handle }
            if let displayName { existing.displayName = displayName }
            if let avatarUrl { existing.avatarUrl = avatarUrl }
            existing.syncedAt = Date()
        } else {
            let cache = SDProfileCache(
                remoteId: userId,
                email: "",
                handle: handle,
                displayName: displayName,
                avatarUrl: avatarUrl
            )
            context.insert(cache)
        }
        try? context.save()
    }

    // MARK: - Cache helpers

    private func upsertCache(_ dto: ProfileDTO) {
        guard let container = modelContainer else { return }
        let context = ModelContext(container)
        let remoteId = dto.id
        let descriptor = FetchDescriptor<SDProfileCache>(
            predicate: #Predicate { $0.remoteId == remoteId }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.email = dto.email
            existing.handle = dto.handle
            existing.displayName = dto.displayName
            existing.avatarUrl = dto.avatarUrl
            existing.role = dto.role
            existing.ageGroup = dto.ageGroup
            existing.gender = dto.gender
            existing.occupation = dto.occupation
            existing.workType = dto.workType
            existing.incomeStatus = dto.incomeStatus
            existing.experienceYears = dto.experienceYears
            existing.bio = dto.bio
            existing.timezone = dto.timezone
            existing.notificationEnabled = dto.notificationEnabled
            existing.onboardingCompleted = dto.onboardingCompleted
            existing.nickname = dto.nickname
            existing.visibility = dto.visibility
            existing.followersCount = dto.followersCount
            existing.followingCount = dto.followingCount
            existing.postsCount = dto.postsCount
            existing.githubUrl = dto.githubUrl
            existing.xUrl = dto.xUrl
            existing.websiteUrl = dto.websiteUrl
            existing.currentStatus = dto.currentStatus
            existing.statusType = dto.statusType
            existing.statusProject = dto.statusProject
            existing.statusStartedAt = dto.statusStartedAt
            existing.statusUpdatedAt = dto.statusUpdatedAt
            existing.createdAt = dto.createdAt
            existing.updatedAt = dto.updatedAt
            existing.syncedAt = Date()
            existing.isDeleted = false
            existing.updatedAtRemote = dto.updatedAt
        } else {
            let cache = SDProfileCache(
                remoteId: dto.id,
                email: dto.email,
                handle: dto.handle,
                displayName: dto.displayName,
                avatarUrl: dto.avatarUrl,
                role: dto.role,
                ageGroup: dto.ageGroup,
                gender: dto.gender,
                occupation: dto.occupation,
                workType: dto.workType,
                incomeStatus: dto.incomeStatus,
                experienceYears: dto.experienceYears,
                bio: dto.bio,
                timezone: dto.timezone,
                notificationEnabled: dto.notificationEnabled,
                onboardingCompleted: dto.onboardingCompleted,
                nickname: dto.nickname,
                visibility: dto.visibility,
                followersCount: dto.followersCount,
                followingCount: dto.followingCount,
                postsCount: dto.postsCount,
                githubUrl: dto.githubUrl,
                xUrl: dto.xUrl,
                websiteUrl: dto.websiteUrl,
                currentStatus: dto.currentStatus,
                statusType: dto.statusType,
                statusProject: dto.statusProject,
                statusStartedAt: dto.statusStartedAt,
                statusUpdatedAt: dto.statusUpdatedAt,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                syncedAt: Date(),
                updatedAtRemote: dto.updatedAt
            )
            context.insert(cache)
        }
        try? context.save()
    }

    private func readFromCacheMyProfile() -> ProfileDTO? {
        guard let idString = UserDefaults.standard.string(forKey: Self.lastKnownMyProfileIdKey),
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return readFromCache(userId: id)
    }

    private func readFromCache(userId: UUID) -> ProfileDTO? {
        guard let container = modelContainer else { return nil }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<SDProfileCache>(
            predicate: #Predicate { $0.remoteId == userId && $0.isDeleted == false }
        )
        guard let row = try? context.fetch(descriptor).first else { return nil }
        return row.toDTO()
    }
}

// MARK: - SDProfileCache → ProfileDTO (JSON round-trip)

private extension SDProfileCache {
    /// `ProfileDTO` は `init(from: Decoder)` のみで memberwise init を持たないため、
    /// JSON serialization 経由で変換する (既存 `SDPostCache.toDTO()` と同型 pattern)。
    func toDTO() -> ProfileDTO? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterNoFrac = ISO8601DateFormatter()
        isoFormatterNoFrac.formatOptions = [.withInternetDateTime]

        func isoString(_ date: Date?) -> String? {
            guard let date else { return nil }
            return isoFormatter.string(from: date)
        }

        var json: [String: Any] = [
            "id": remoteId.uuidString,
            "email": email,
            "role": role,
            "timezone": timezone,
            "notification_enabled": notificationEnabled,
            "onboarding_completed": onboardingCompleted,
            "visibility": visibility,
            "followers_count": followersCount,
            "following_count": followingCount,
            "posts_count": postsCount,
            "created_at": isoFormatter.string(from: createdAt),
            "updated_at": isoFormatter.string(from: updatedAt)
        ]
        if let handle { json["handle"] = handle }
        if let displayName { json["display_name"] = displayName }
        if let avatarUrl { json["avatar_url"] = avatarUrl }
        if let ageGroup { json["age_group"] = ageGroup }
        if let gender { json["gender"] = gender }
        if let occupation { json["occupation"] = occupation }
        if let workType { json["work_type"] = workType }
        if let incomeStatus { json["income_status"] = incomeStatus }
        if let experienceYears { json["experience_years"] = experienceYears }
        if let bio { json["bio"] = bio }
        if let nickname { json["nickname"] = nickname }
        if let githubUrl { json["github_url"] = githubUrl }
        if let xUrl { json["x_url"] = xUrl }
        if let websiteUrl { json["website_url"] = websiteUrl }
        if let currentStatus { json["current_status"] = currentStatus }
        if let statusType { json["status_type"] = statusType }
        if let statusProject { json["status_project"] = statusProject }
        if let s = isoString(statusStartedAt) { json["status_started_at"] = s }
        if let s = isoString(statusUpdatedAt) { json["status_updated_at"] = s }

        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        let decoder = JSONDecoder()
        // ISO8601DateFormatter は非 Sendable のため、`.custom` の @Sendable closure に
        // 外側 formatter を capture できない。closure 内で都度生成する (formatter 生成は
        // 軽量で N+1 level perf 影響なし)。
        decoder.dateDecodingStrategy = .custom { decoder in
            let fracFormatter = ISO8601DateFormatter()
            fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let plainFormatter = ISO8601DateFormatter()
            plainFormatter.formatOptions = [.withInternetDateTime]

            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = fracFormatter.date(from: string) { return date }
            if let date = plainFormatter.date(from: string) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO8601 date: \(string)"
            )
        }
        return try? decoder.decode(ProfileDTO.self, from: data)
    }
}
