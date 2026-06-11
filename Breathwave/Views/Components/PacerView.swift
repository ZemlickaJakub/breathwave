import SwiftUI

/// Breathing pacer: a circle filling with a wave — the water rises on inhale,
/// holds steady, and falls on exhale.
struct PacerView: View {
    let snapshot: BreathingEngine.Snapshot?
    /// Current time driving the idle wave motion (pass the TimelineView date).
    let time: TimeInterval

    private static let emptyLevel = 0.3
    private static let fullLevel = 0.85

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
        let range = Self.fullLevel - Self.emptyLevel
        switch snapshot.phase {
        case .inhale:
            return Self.emptyLevel + range * snapshot.phaseProgress
        case .holdAfterInhale:
            return Self.fullLevel
        case .exhale:
            return Self.fullLevel - range * snapshot.phaseProgress
        case .holdAfterExhale:
            return Self.emptyLevel
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
