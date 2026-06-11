import CoreHaptics

/// Haptic guidance: rising intensity on inhale, falling on exhale, steady on holds.
/// TODO(Fáze 1): CHHapticEngine with a custom pattern per phase.
@MainActor
final class HapticsEngine {
    func play(_ phase: BreathPhase, duration: TimeInterval) {
        // TODO(Fáze 1)
    }

    func stop() {
        // TODO(Fáze 1)
    }
}
