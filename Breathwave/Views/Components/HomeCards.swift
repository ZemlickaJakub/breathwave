import SwiftUI

/// Card for a breathing protocol on the home screen.
struct ProtocolCard: View {
    let breathingProtocol: BreathingProtocol

    var body: some View {
        HStack(spacing: 14) {
            CardIcon(systemImage: "water.waves")
            VStack(alignment: .leading, spacing: 3) {
                Text(breathingProtocol.localizedName)
                    .font(.headline)
                    .fontDesign(.serif)
                Text(verbatim: "\(breathingProtocol.rhythmSummary) s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CardChevron()
        }
        .cardChrome()
    }
}

/// Card for the meditation rows on the home screen.
struct MenuCard: View {
    let titleKey: LocalizedStringKey
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            CardIcon(systemImage: icon)
            Text(titleKey)
                .font(.headline)
                .fontDesign(.serif)
            Spacer()
            CardChevron()
        }
        .cardChrome()
    }
}

private struct CardIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(.tint)
            .frame(width: 40, height: 40)
            .background(.tint.opacity(0.12), in: Circle())
    }
}

private struct CardChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.tertiary)
    }
}
