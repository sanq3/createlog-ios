import Foundation
import SwiftData

/// オフライン時に発行された mutation を SwiftData に永続化するキューエントリ。
///
/// アプリ再起動を跨いでも drain 対象が失われないよう全フィールドをディスクに保存する。
/// lightweight migration を壊さないため、全プロパティにデフォルト値を持たせている
/// (新規フィールド追加時に既存行が NULL で落ちないようにする保険)。
///
/// ## Drain priority (FK 依存順、1-indexed、`SyncEntityType.drainPriority` と一致)
/// ```
/// 1 profile       (profiles table、FK root)
/// 2 project       (apps table、profiles 依存)
/// 3 category      (categories table、profiles 依存)
/// 4 log           (logs table、profiles + project + category 依存)
/// 5 post          (posts table、profiles + log 依存)
/// 6 comment       (comments table、profiles + post 依存)
/// 7 like          (likes table、profiles + post 依存)
/// 8 follow        (follows table、profiles 依存)
/// 9 notification  (notifications table、mark-as-read のみ)
/// 99 sentinel     (SyncEntityType 不明時の保険値、drain 対象から実質除外)
/// ```
/// Source of truth は `SyncEntityType.drainPriority`。enqueue 側は必ず
/// `SyncEntityType.xxx.drainPriority` を代入すること (手打ち数値禁止)。
@Model
final class SDOfflineOperation {
    // MARK: - Identity
    var id: UUID = UUID()
    /// サーバー upsert の冪等キー。同一キーが 2 回届いても 1 回分だけ反映される。
    var idempotencyKey: UUID = UUID()

    // MARK: - Operation
    /// "profile" | "project" | "category" | "log" | "post" | "comment" | "like" | "follow" | "notification"
    var entityType: String = ""
    /// "insert" | "update" | "delete"
    var operationType: String = ""
    /// JSON-encoded DTO (Codable → Data)
    var payload: Data = Data()
    /// FK 依存順の drain priority (上記 priority table 参照、1-indexed)。
    /// Source of truth: `SyncEntityType.drainPriority`。
    /// `99` sentinel: lightweight migration fallback 用の「最低優先度」マーカー。
    /// enqueue 経路では必ず `SyncEntityType.xxx.drainPriority` が渡されるため、
    /// 実行時に 99 が観測されるのは migration で default 値が残った行のみ (drain 実質スキップ)。
    var priority: Int = 99

    // MARK: - Retry state
    var createdAt: Date = Date()
    var attemptCount: Int = 0
    var lastAttemptAt: Date?
    var lastError: String?
    /// 次回リトライ可能時刻。`Date.distantPast` = 即リトライ可 (enqueue 直後のデフォルト)。
    /// SwiftData の #Predicate が optional の forced unwrap をサポートしないため、
    /// nullable ではなく sentinel value で「すぐ retry OK」を表現する。
    var nextRetryAt: Date = Date.distantPast
    var isDeadLetter: Bool = false

    init(
        id: UUID = UUID(),
        idempotencyKey: UUID = UUID(),
        entityType: String,
        operationType: String,
        payload: Data,
        priority: Int
    ) {
        self.id = id
        self.idempotencyKey = idempotencyKey
        self.entityType = entityType
        self.operationType = operationType
        self.payload = payload
        self.priority = priority
        self.createdAt = Date()
    }
}

// MARK: - Typed accessors

/// `entityType` / `operationType` は SwiftData の `#Predicate` 制約で `String` のまま保持するが、
/// 呼び出し側では enum 経由で型安全にアクセスする。
/// 不正な rawValue (手動 DB 編集 or 旧バージョンからの migration で古い値) は `nil` を返す。
extension SDOfflineOperation {
    var syncEntityType: SyncEntityType? {
        SyncEntityType(rawValue: entityType)
    }

    var syncOperationType: SyncOperationType? {
        SyncOperationType(rawValue: operationType)
    }
}
