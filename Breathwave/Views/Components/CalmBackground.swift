import SwiftUI

/// Warm, sand-and-morning-light gradient shared by the main screens.
/// Light mode: cream into golden sand; dark mode: warm deep tones.
struct CalmBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [Color(.backgroundTop), Color(.backgroundBottom)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
    }
}

extension View {
    func calmBackground() -> some View {
        modifier(CalmBackground())
    }
}
