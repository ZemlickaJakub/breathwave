import SwiftUI

/// Quiet uppercase section label shared by home, stats and settings.
struct SectionHeader: View {
    let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.secondary)
    }
}
