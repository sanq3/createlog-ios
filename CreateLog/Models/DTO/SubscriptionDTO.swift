import Foundation

/// Supabase `subscriptions` テーブル対応 DTO
///
/// T4 (2026-04-12): StoreKit 2 連携 + free/premium プラン管理
struct SubscriptionDTO: Codable, Sendable {
    let id: UUID
    let userId: UUID
    /// "active" / "inactive" / "canceled" / "past_due"
    let status: String
    /// "free" / "premium"
    let planType: String
    /// "stripe" / "app_store"
    let provider: String?
    let providerSubscriptionId: String?
    let providerCustomerId: String?
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let cancelAtPeriodEnd: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case status
        case planType = "plan_type"
        case provider
        case providerSubscriptionId = "provider_subscription_id"
        case providerCustomerId = "provider_customer_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// StoreKit から同期する際の upsert payload
struct SubscriptionUpsertDTO: Codable, Sendable {
    let userId: UUID
    let status: String
    let planType: String
    let provider: String?
    let providerSubscriptionId: String?
    let currentPeriodStart: Date?
    let currentPeriodEnd: Date?
    let cancelAtPeriodEnd: Bool

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case status
        case planType = "plan_type"
        case provider
        case providerSubscriptionId = "provider_subscription_id"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case cancelAtPeriodEnd = "cancel_at_period_end"
    }
}
