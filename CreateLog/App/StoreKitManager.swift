import StoreKit
import Foundation

/// StoreKit 2 によるサブスクリプション管理
@MainActor @Observable
final class StoreKitManager {

    // MARK: - State

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false
    var errorMessage: String?

    var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }

    // MARK: - Product IDs

    private static let productIDs = ["com.sanq3.createlog.premium.monthly"]

    // MARK: - Init

    @ObservationIgnored private var updateTask: Task<Void, Never>?

    init() {
        updateTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit {
        updateTask?.cancel()
    }

    // MARK: - Actions

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
            await updatePurchasedProducts()
        } catch {
            errorMessage = "商品情報の取得に失敗しました"
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                errorMessage = "購入の承認待ちです"
            @unknown default:
                break
            }
        } catch {
            errorMessage = "購入に失敗しました"
        }
    }

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        await updatePurchasedProducts()
    }

    // MARK: - Private

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                purchased.insert(transaction.productID)
            }
        }
        purchasedProductIDs = purchased
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                purchasedProductIDs.insert(transaction.productID)
                await transaction.finish()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let value):
            return value
        }
    }
}

enum StoreError: Error, LocalizedError {
    case verificationFailed

    var errorDescription: String? {
        "購入の検証に失敗しました"
    }
}
