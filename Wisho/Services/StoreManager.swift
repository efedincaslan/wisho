import Foundation
import StoreKit
import Observation

@MainActor
@Observable
final class StoreManager {
    static let yearlyID = "wisho.pro.yearly"
    static let monthlyID = "wisho.pro.monthly"
    static let productIDs = [yearlyID, monthlyID]

    /// Free tier tracks up to this many people.
    static let freePersonLimit = 10

    private(set) var isPro = false
    private(set) var products: [Product] = []

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    func loadProducts() async {
        products = (try? await Product.products(for: Self.productIDs)) ?? []
    }

    func refreshEntitlements() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               Self.productIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
        // The widget can't talk to StoreKit — mirror PRO status to the shared defaults.
        UserDefaults(suiteName: AppGroup.identifier)?.set(pro, forKey: AppGroup.isProKey)
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    func canAddPerson(currentCount: Int) -> Bool {
        isPro || currentCount < Self.freePersonLimit
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}
