import CoreHaptics

/// Haptic guidance: rising intensity on inhale, falling on exhale,
/// a soft tap at the start of each hold. Foreground only — CoreHaptics
/// does not play with the screen off (audio covers that case).
@MainActor
final class HapticsEngine {
    private var engine: CHHapticEngine?

    var isAvailable: Bool {
        CHHapticEngine.capabilitiesForHardware().supportsHaptics
    }

    func prepare() {
        guard isAvailable, engine == nil else { return }
        do {
            let engine = try CHHapticEngine()
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.engine = nil
                    self?.prepare()
                }
            }
            try engine.start()
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func play(_ phase: BreathPhase, duration: TimeInterval) {
        guard let engine, duration > 0 else { return }
        let pattern: CHHapticPattern?
        switch phase {
        case .inhale:
            pattern = try? rampPattern(from: 0.25, to: 0.9, duration: duration)
        case .exhale:
            pattern = try? rampPattern(from: 0.9, to: 0.25, duration: duration)
        case .holdAfterInhale, .holdAfterExhale:
            pattern = try? tapPattern()
        }
        guard let pattern, let player = try? engine.makePlayer(with: pattern) else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    private func rampPattern(from: Float, to: Float, duration: TimeInterval) throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
            ],
            relativeTime: 0,
            duration: duration
        )
        let curve = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: from),
                .init(relativeTime: duration, value: to),
            ],
            relativeTime: 0
        )
        return try CHHapticPattern(events: [event], parameterCurves: [curve])
    }

    private func tapPattern() throws -> CHHapticPattern {
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0
        )
        return try CHHapticPattern(events: [event], parameterCurves: [])
    }
}
