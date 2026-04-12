import Foundation

/// オフライン同期の状態遷移を表す。
/// - `local`: SwiftData にのみ保存、まだ queue 未登録 (migration 直後など)
/// - `queued`: `SDOfflineOperation` 生成済、ネットワーク復帰 or drain トリガー待ち
/// - `syncing`: drain ループで現在処理中 (排他用)
/// - `synced`: サーバー反映完了 (remoteId 確定済)
/// - `failed`: リトライ可能エラー → `queued` に戻す
/// - `conflict`: 409 / updatedAt 矛盾 (T7b の LWW で使用、T7a-1 では未到達)
/// - `deadLetter`: 20 回リトライ失敗、ユーザー介入が必要
enum SyncStatus: String, Codable, Sendable, CaseIterable {
    case local
    case queued
    case syncing
    case synced
    case failed
    case conflict
    case deadLetter
}
