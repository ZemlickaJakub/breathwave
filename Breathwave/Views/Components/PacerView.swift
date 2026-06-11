import SwiftUI

/// Scaffold pacer: a circle that grows on inhale, shrinks on exhale.
/// TODO(Fáze 1): replace with the wave animation (Canvas + WaveShape).
struct PacerView: View {
    let snapshot: BreathingEngine.Snapshot?

    private static let minScale = 0.6
    private static let maxScale = 1.0

    var body: some View {
        VStack(spacing: 32) {
            Circle()
                .fill(.tint.opacity(0.35))
                .overlay(Circle().strokeBorder(.tint, lineWidth: 2))
                .frame(width: 220, height: 220)
                .scaleEffect(scale)
            Text(phaseLabel)
                .font(.title2)
        }
    }

    private var scale: Double {
        guard let snapshot else { return Self.minScale }
        let range = Self.maxScale - Self.minScale
        switch snapshot.phase {
        case .inhale:
            return Self.minScale + range * snapshot.phaseProgress
        case .holdAfterInhale:
            return Self.maxScale
        case .exhale:
            return Self.maxScale - range * snapshot.phaseProgress
        case .holdAfterExhale:
            return Self.minScale
        }
    }

    private var phaseLabel: LocalizedStringKey {
        guard let snapshot else { return "Ready" }
        switch snapshot.phase {
        case .inhale: return "Breathe In"
        case .holdAfterInhale, .holdAfterExhale: return "Hold"
        case .exhale: return "Breathe Out"
        }
    }
}
