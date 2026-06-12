import StoreKit
import SwiftUI

/// Tip jar section for AboutView's List.
struct TipJarView: View {
    @State private var manager = TipJarManager()

    var body: some View {
        Section {
            if manager.products.isEmpty {
                Text(manager.isLoading ? "Loading…" : "Tips are unavailable right now.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(manager.products) { product in
                    Button {
                        Task { await manager.purchase(product) }
                    } label: {
                        LabeledContent(product.displayName) {
                            Text(product.displayPrice)
                        }
                    }
                    .tint(.primary)
                }
            }
            if manager.hasThanked {
                Text("Thank you! 🌊")
            }
        } header: {
            Text("Support Breathwave")
        } footer: {
            Text("Breathwave is free and ad-free. Tips support development and unlock nothing.")
        }
        .task { await manager.loadProducts() }
    }
}
