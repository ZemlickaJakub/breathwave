import SwiftUI

/// Breathing pacer: a circle filling with a wave — the water rises on inhale,
/// holds steady, and falls on exhale.
struct PacerView: View {
    let snapshot: BreathingEngine.Snapshot?
    /// Current time driving the idle wave motion (pass the TimelineView date).
    let time: TimeInterval
    /// Om training shows "Om" instead of "Breathe Out".
    var exhaleLabel: LocalizedStringKey = "Breathe Out"

    /// Exhale empties the lungs — the water drops to a small puddle,
    /// not a hard zero, so the circle never looks dead.
    private static let emptyLevel = 0.08
    private static let fullLevel = 0.95

    var body: some View {
        VStack(spacing: 32) {
            ZStack {
                WaveShape(level: level, phase: time * 1.4, amplitude: 0.05)
                    .fill(.tint.opacity(0.3))
                WaveShape(level: level, phase: time * 1.0 + .pi / 1.5, amplitude: 0.035)
                    .fill(.tint.opacity(0.45))
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.tint.opacity(0.5), lineWidth: 2))
            .frame(width: 240, height: 240)
            Text(phaseLabel)
                .font(.title2)
        }
    }

    private var level: Double {
        guard let snapshot else { return Self.emptyLevel }
        return Self.emptyLevel + (Self.fullLevel - Self.emptyLevel) * snapshot.lungFill
    }

    private var phaseLabel: LocalizedStringKey {
        guard let snapshot else { return "Ready" }
        switch snapshot.phase {
        case .inhale: return "Breathe In"
        case .holdAfterInhale, .holdAfterExhale: return "Hold"
        case .exhale: return exhaleLabel
        }
    }
}
