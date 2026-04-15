import Foundation

/// オフライン queue が扱う entity の型を表す。
///
/// `SDOfflineOperation.entityType` は SwiftData `#Predicate` の制約から `String` のまま保持するが、
/// 呼び出し側 (ViewModel / Repository / Decorator) では `SyncEntityType.project.rawValue` のように
/// 型安全に生成し、文字列のタイポを防ぐために使う。
///
/// ## Drain priority
/// `drainPriority` 計算プロパティで FK 依存順 (親→子) を表現する。
/// 小さい値が先に drain される。Raw value は String を明示指定して Codable stable 化。
enum SyncEntityType: String, Codable, CaseIterable, Sendable {
    case profile = "profile"
    case project = "project"
    case category = "category"
    case log = "log"
    case post = "post"
    case comment = "comment"
    case like = "like"
    case bookmark = "bookmark"
    case follow = "follow"
    case notification = "notification"

    /// drain 優先度。小さいほど先に処理 (FK 依存順)。
    /// `SDOfflineOperation.priority` フィールドには `drainPriority` の値を入れる前提で設計。
    var drainPriority: Int {
        switch self {
        case .profile: return 1
        case .project: return 2
        case .category: return 3
        case .log: return 4
        case .post: return 5
        case .comment: return 6
        case .like: return 7
        case .bookmark: return 8
        case .follow: return 9
        case .notification: return 10
        }
    }
}
