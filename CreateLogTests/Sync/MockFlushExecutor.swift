import Foundation
@testable import CreateLog

/// テスト用の `FlushExecuting` スタブ。
///
/// - `executedSnapshots`: `execute(_:)` に渡された snapshot 履歴 (順序保持)
/// - `setError(_:)`: 次以降の `execute(_:)` で throw する error (nil で成功に戻す)
/// - `supportedEntityTypes`: 構築時に任意指定 (未登録 entity 経路の検証用)
///
/// `MockNetworkMonitor` と同じく `NSLock` で値を保護し、test helper として使う。
final class MockFlushExecutor: FlushExecuting, @unchecked Sendable {
    private let lock = NSLock()
    private var _executedSnapshots: [QueuedOperationSnapshot] = []
    private var _errorToThrow: (any Error)?

    let supportedEntityTypes: [String]

    init(supportedEntityTypes: [String] = [SyncEntityType.log.rawValue]) {
        self.supportedEntityTypes = supportedEntityTypes
    }

    /// `execute(_:)` が呼ばれた snapshot 一覧 (order preserved)。
    var executedSnapshots: [QueuedOperationSnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return _executedSnapshots
    }

    /// 次以降の `execute(_:)` で throw する error を設定する。
    /// nil を渡すと成功モードに戻る。
    func setError(_ error: (any Error)?) {
        lock.lock()
        _errorToThrow = error
        lock.unlock()
    }

    func execute(_ snapshot: QueuedOperationSnapshot) async throws {
        lock.lock()
        _executedSnapshots.append(snapshot)
        let err = _errorToThrow
        lock.unlock()
        if let err {
            throw err
        }
    }
}
