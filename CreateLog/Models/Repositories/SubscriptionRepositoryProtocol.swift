import Foundation

/// サブスクリプション管理 Repository
///
/// T4 (2026-04-12): StoreKit 2 連携 + free/premium プラン管理
protocol SubscriptionRepositoryProtocol: Sendable {
    /// 自分の現在の subscription を取得 (未登録なら nil)
    func fetchCurrentSubscription() async throws -> SubscriptionDTO?
    /// StoreKit transaction から subscription を upsert (成功時: 最新の DTO を返す)
    func upsertFromStoreKit(_ upsert: SubscriptionUpsertDTO) async throws -> SubscriptionDTO
}
