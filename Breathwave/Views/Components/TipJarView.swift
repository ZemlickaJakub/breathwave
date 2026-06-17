import StoreKit
import SwiftUI

/// Tip jar section for AboutView's List.
struct TipJarView: View {
    @State private var manager = TipJarManager()

    // Screenshot-only: real prices come from StoreKit, which does not load in the
    // headless screenshot pipeline. Gated behind a launch argument never passed in production.
    private static let screenshotMock = CommandLine.arguments.contains("-screenshot.mockTips")
    private static let mockTipRows: [(name: String, price: String)] = [
        ("Small tip", "$0.99"),
        ("Medium tip", "$2.99"),
        ("Large tip", "$4.99"),
        ("Patron tip", "$9.99"),
    ]

    var body: some View {
        Section {
            if Self.screenshotMock {
                ForEach(Self.mockTipRows, id: \.name) { tip in
                    LabeledContent(tip.name) { Text(tip.price) }
                        .tint(.primary)
                }
            } else if manager.products.isEmpty {
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
