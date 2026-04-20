import Foundation
import SwiftData
import os

/// memo フィールドに埋め込まれた remoteId UUID を SDLogCache に移行する 1 回限りの migration actor。
///
/// ## 背景 (T7b)
/// 旧実装 (`RecordingViewModel`) が `SDTimeEntry.memo` フィールドに remote `logs.id` (UUID 文字列) を
/// ハック的に格納していた (L337)。T7b で memo ハックを撤廃し、SDLogCache.remoteId で紐付けを行う。
///
/// ## 方式 B (team-lead 承認済)
/// - 全 `SDTimeEntry` を fetch → `memo` が UUID 文字列の場合のみ `SDLogCache` を生成 (remoteId = UUID)
/// - SDTimeEntry 側の `memo` は温存 (破壊しない、互換性保持)
/// - `UserDefaults("migratedLogMemoRemoteIds")` で 1 回限り guard
/// - 失敗は warning log、移行続行 (best-effort)
///
/// ## 呼び出しタイミング
/// 2026-04-20: 認証完了後に呼ぶ (以前は App init 即時実行で userId 不明のため UUID() 暫定値を入れていた)。
/// `CreateLogApp` の authState が `.authenticated` になったタイミングで 1 回だけ kick。
/// 未認証時は呼ばない (anon UUID を SDLogCache.userId に埋める silent 破綻を防止)。
@ModelActor
actor MigrationService {
    private static let logger = Logger(subsystem: "com.sanq3.createlog", category: "MigrationService")
    private static let migrationKey = "migratedLogMemoRemoteIds"

    /// memo ハック migration を実行する。2 回目以降は no-op。
    /// - Parameter userId: 認証済みユーザーの Supabase auth UID。
    ///   SDLogCache.userId に設定する。将来 userId 別の cache filter を追加した際の整合性担保。
    func migrateLogMemoRemoteIds(userId: UUID) {
        guard !UserDefaults.standard.bool(forKey: Self.migrationKey) else {
            Self.logger.debug("migrateLogMemoRemoteIds: already migrated, skipping")
            return
        }

        do {
            let descriptor = FetchDescriptor<SDTimeEntry>()
            let entries = try modelContext.fetch(descriptor)
            var migratedCount = 0

            for entry in entries {
                guard let memo = entry.memo,
                      let remoteId = UUID(uuidString: memo) else {
                    continue
                }

                // SDLogCache に既に存在するか check
                let existing = FetchDescriptor<SDLogCache>(
                    predicate: #Predicate { $0.remoteId == remoteId }
                )
                guard (try? modelContext.fetchCount(existing)) == 0 else {
                    continue
                }

                // SDLogCache 生成 (最小限、remote fetch で後から上書きされる)
                let cache = SDLogCache(
                    remoteId: remoteId,
                    userId: userId,
                    title: entry.projectName,
                    categoryId: UUID(), // categoryName → UUID 解決は sync 時
                    startedAt: entry.startDate,
                    endedAt: entry.endDate,
                    durationMinutes: entry.durationMinutes,
                    isTimer: false,
                    syncedAt: Date.distantPast, // 即 revalidate トリガ
                    isDeleted: false,
                    updatedAtRemote: Date.distantPast
                )
                modelContext.insert(cache)
                migratedCount += 1
            }

            if migratedCount > 0 {
                try modelContext.save()
                Self.logger.info("migrateLogMemoRemoteIds: migrated \(migratedCount) entries for user \(userId)")
            }

            UserDefaults.standard.set(true, forKey: Self.migrationKey)
        } catch {
            Self.logger.warning("migrateLogMemoRemoteIds failed (best-effort): \(error.localizedDescription)")
        }
    }
}
