import Observation
import StoreKit

/// Voluntary tips (consumable IAP). Nothing is unlocked — pure support.
@MainActor
@Observable
final class TipJarManager {
    nonisolated static let productIDs = [
        "cz.jakubzemlicka.breathwave.tip.small",
        "cz.jakubzemlicka.breathwave.tip.medium",
        "cz.jakubzemlicka.breathwave.tip.large",
        "cz.jakubzemlicka.breathwave.tip.patron",
    ]

    private(set) var products: [Product] = []
    private(set) var hasThanked = false
    private(set) var isLoading = true

    func loadProducts() async {
        defer { isLoading = false }
        let loaded = (try? await Product.products(for: Self.productIDs)) ?? []
        products = loaded.sorted { $0.price < $1.price }
    }

    func purchase(_ product: Product) async {
        guard let result = try? await product.purchase() else { return }
        if case .success(let verification) = result,
           case .verified(let transaction) = verification {
            await transaction.finish()
            hasThanked = true
        }
    }
}
