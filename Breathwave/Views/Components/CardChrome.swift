import SwiftUI

extension View {
    /// Shared card look: soft material, rounded corners, gentle shadow.
    func cardChrome() -> some View {
        padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 5)
    }
}
