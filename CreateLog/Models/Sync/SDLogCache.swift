import Foundation
import SwiftData

/// Remote `logs` テーブルの local cache。Offline-first 同期の読み出し側 cache として使う。
///
/// ## 役割分担 (T7a 内での位置付け)
/// - `SDOfflineOperation`: local 側 mutation を queue 化する **書き込み側** キュー
/// - `SDLogCache` (このファイル): remote 側 log データを local に保持する **読み出し側** キャッシュ
/// - `SDTimeEntry` (既存、オンボーディング用): sync 対象外、将来的に deprecate 予定
///
/// ## T7a-3 scope の最小カラムセット
/// 現状の `LogDTO` は 9 カラム。T4-B で ProfileDTO 19→31 拡張が予定されているが、
/// `LogDTO` の拡張 (hashtag_ids / image_urls / etc.) は T7b マージ時に取り込む。
/// 今はここに存在するカラムのみで最小 cache を切る (T4 完了待たずに T7a-3 進める戦略)。
///
/// ## lightweight migration 要件 (T7a-1 教訓)
/// 全非 optional プロパティに宣言時 default 値を持たせる。SwiftData の lightweight migration は
/// default 値なしフィールドを追加するだけで既存行が NULL で破損するため。
/// `endedAt` のみ optional (進行中 Timer でも cache に入れられるよう nil 許容)。
///
/// ## 書き込み経路 (T7b 予定、T7a-3 scope 外)
/// - `OfflineSyncService.flush()` → `LogFlushExecutor.execute()` → remote insert/update/delete
/// - 成功時に remote のレスポンスをこの cache に upsert する
/// - LWW 比較は `updatedAtRemote` で行う
@Model
final class SDLogCache {
    // MARK: - Primary identity

    /// Remote `logs.id` (UUID PK)。
    /// local 側は PK として使い、SDOfflineOperation の payload に含めて送信する。
    var remoteId: UUID = UUID()

    /// 所有者 `profiles.id`。RLS filter 用。
    var userId: UUID = UUID()

    // MARK: - Core fields (LogDTO 最小 subset)

    var title: String = ""
    var categoryId: UUID = UUID()
    var startedAt: Date = Date()
    /// 進行中 Timer の場合は nil (T7b で Timer 連動時に使用)。
    var endedAt: Date? = nil
    var durationMinutes: Int = 0
    var isTimer: Bool = false

    // MARK: - Cache metadata

    /// local cache の最終更新時刻 (SWR 判定用)。
    /// stale-while-revalidate pattern で「古いが返す、裏で refresh」の判定に使う。
    var syncedAt: Date = Date()

    /// Tombstone フラグ。remote 削除を local cache に反映する際に true にする。
    /// cascade delete 不要 (SDOfflineOperation とは FK 関係なし)。
    var isDeleted: Bool = false

    /// Remote 側の `updated_at` timestamp。LWW (Last Write Wins) conflict resolution に使う。
    var updatedAtRemote: Date = Date()

    init(
        remoteId: UUID,
        userId: UUID,
        title: String,
        categoryId: UUID,
        startedAt: Date,
        endedAt: Date? = nil,
        durationMinutes: Int,
        isTimer: Bool = false,
        syncedAt: Date = Date(),
        isDeleted: Bool = false,
        updatedAtRemote: Date = Date()
    ) {
        self.remoteId = remoteId
        self.userId = userId
        self.title = title
        self.categoryId = categoryId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationMinutes = durationMinutes
        self.isTimer = isTimer
        self.syncedAt = syncedAt
        self.isDeleted = isDeleted
        self.updatedAtRemote = updatedAtRemote
    }
}
