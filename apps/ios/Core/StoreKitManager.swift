import Foundation
import StoreKit

@MainActor
public class StoreKitManager: ObservableObject {
    public static let shared = StoreKitManager()
    
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs = Set<String>()
    
    private var transactionListener: Task<Void, Error>?
    
    public var isPremium: Bool {
        !purchasedProductIDs.isEmpty
    }
    
    private init() {
        transactionListener = listenForTransactions()
        Task {
            await updatePurchasedProducts()
            await fetchProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    public func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: ["com.fluence.premium.monthly", "com.fluence.premium.yearly"])
            self.products = storeProducts.sorted(by: { $0.price < $1.price })
        } catch {
            print("Failed product fetch: \(error)")
        }
    }
    
    public func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }
    
    public func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    purchasedIDs.insert(transaction.productID)
                }
            }
        }
        self.purchasedProductIDs = purchasedIDs
    }
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("Transaction update failed: \(error)")
                }
            }
        }
    }
    
    public func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }
}

public enum StoreError: Error {
    case failedVerification
}
