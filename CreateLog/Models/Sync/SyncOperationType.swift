import Foundation

/// オフライン queue の mutation 種別を表す。
///
/// `SDOfflineOperation.operationType` は SwiftData `#Predicate` の制約から `String` のまま保持するが、
/// 呼び出し側 (ViewModel / Repository / Decorator) では `SyncOperationType.insert.rawValue` のように
/// 型安全に生成し、文字列のタイポを防ぐために使う。
/// Raw value は String を明示指定して Codable stable 化。
enum SyncOperationType: String, Codable, CaseIterable, Sendable {
    case insert = "insert"
    case update = "update"
    case delete = "delete"
}
