import Foundation
import os

/// Domain 横断イベントの publish/subscribe hub。
///
/// ## 同期方針 (NetworkMonitor.swift の pattern を踏襲)
/// - State (continuations map) を `OSAllocatedUnfairLock<State>` で保護し、
///   `@unchecked Sendable` を安全に成立させる。
/// - publish 時は lock 内で snapshot 取得 → lock 外で yield。
///   (yield 中に consumer 側 onTermination が同期発火した場合、onTermination 内で
///   再度 lock を取りに来るため nested lock deadlock の可能性がある
///   `OSAllocatedUnfairLock` は非再帰。snapshot pattern で回避する。)
/// - close() は snapshot + removeAll を lock 内で実施 → lock 外で finish()。
///
/// ## 使い方
/// ```swift
/// // Publisher (Repository 層)
/// await bus.publish(.postCreated(newPost))
///
/// // Subscriber (ViewModel 内)
/// .task {
///     for await event in bus.events() {
///         switch event {
///         case .postCreated(let post): posts.insert(post, at: 0)
///         default: break
///         }
///     }
/// }
/// ```
///
/// ## 設計判断: class + OSAllocatedUnfairLock (not actor)
/// CreateLog の既存 AsyncStream pattern (NetworkMonitor / OfflineSyncService 等) と同じく
/// `final class @unchecked Sendable` + OSAllocatedUnfairLock で構築。
/// - actor だと publish() が async required になり、Repository 成功ハンドラ
///   (async context だが同期で発火したい) から余計な suspension が入る。
/// - NetworkMonitor と同一パターンで一貫性を保つ。
final class DomainEventBus: @unchecked Sendable {
    private struct State {
        var continuations: [UUID: AsyncStream<DomainEvent>.Continuation] = [:]
    }

    private let lock = OSAllocatedUnfairLock<State>(initialState: State())

    init() {}

    /// イベントを全 subscriber に broadcast。
    /// Repository 層や Service 層の write 成功時に呼ぶ。
    func publish(_ event: DomainEvent) {
        let snapshot = lock.withLock { state -> [AsyncStream<DomainEvent>.Continuation] in
            Array(state.continuations.values)
        }
        for continuation in snapshot {
            continuation.yield(event)
        }
    }

    /// subscribe。View/ViewModel の `.task` 内で `for await` する。
    /// 初期値は yield しない (event bus は pub/sub であり state holder ではない)。
    ///
    /// ## Buffering
    /// `.bufferingNewest(64)` で slow consumer (MainActor で重い patch ループ中等) に積まれ
    /// 続けるのを防ぐ。64 件超過時は古い event を捨てる (UI patch の loss は次回 fetch で解消)。
    /// default `.unbounded` は memory leak になる。
    ///
    /// ## Termination race 対策
    /// `onTermination` の設定は lock 獲得 **より前** に置く。こうすると
    /// register 直後の immediate cancellation でも onTermination handler が呼ばれ、
    /// map 内から自分の id が確実に外れる (race window を閉じる)。
    func events() -> AsyncStream<DomainEvent> {
        AsyncStream<DomainEvent>(bufferingPolicy: .bufferingNewest(64)) { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }
            let id = UUID()
            // onTermination を lock 獲得より先に設定 (HIGH #4: NetworkMonitor 由来の race 対策)。
            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { state in
                    _ = state.continuations.removeValue(forKey: id)
                }
            }
            lock.withLock { state in
                state.continuations[id] = continuation
            }
        }
    }

    /// 全 subscriber を強制終了。App 終了や test teardown 時のみ想定。
    func close() {
        let snapshot = lock.withLock { state -> [AsyncStream<DomainEvent>.Continuation] in
            let all = Array(state.continuations.values)
            state.continuations.removeAll()
            return all
        }
        for continuation in snapshot {
            continuation.finish()
        }
    }
}
