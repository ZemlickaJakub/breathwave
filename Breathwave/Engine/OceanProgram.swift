import Foundation

/// Pure, sample-rate-independent description of the ocean soundtrack.
/// The surf swells with the inhale (louder, brighter) and recedes with the
/// exhale; holds are a quiet murmur — the ocean never goes fully silent.
/// `value(at:)` runs on the realtime audio thread — keep it allocation-free.
struct OceanProgram: Equatable, Sendable {
    /// Sound character: surf has a deep rumble, breeze is light and airy.
    enum Timbre: Equatable, Sendable {
        case surf
        case breeze
    }

    struct Segment: Equatable, Sendable {
        var duration: TimeInterval
        /// Low-pass cutoff in Hz — higher sounds like a closer, breaking wave.
        var startCutoff: Double
        var endCutoff: Double
        var startAmplitude: Double
        var endAmplitude: Double
    }

    var segments: [Segment]
    var timbre: Timbre = .surf

    var cycleDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    static let lowCutoff: Double = 320
    static let highCutoff: Double = 1400
    static let holdAmplitude: Double = 0.15

    /// Cutoff range per timbre — breeze lives higher, with no deep rumble.
    private static func cutoffRange(for timbre: Timbre) -> (low: Double, high: Double) {
        switch timbre {
        case .surf: (lowCutoff, highCutoff)
        case .breeze: (700, 2600)
        }
    }

    /// Breath-synced surf: the wave builds during the inhale and washes out
    /// during the exhale. Amplitude steps between segments are smoothed by
    /// the renderer's slew, which is what makes the "crash" feel natural.
    static func breathing(_ breathingProtocol: BreathingProtocol, timbre: Timbre = .surf) -> OceanProgram {
        let (low, high) = cutoffRange(for: timbre)
        let segments = breathingProtocol.phases.map { spec -> Segment in
            switch spec.phase {
            case .inhale:
                Segment(duration: spec.duration, startCutoff: low, endCutoff: high,
                        startAmplitude: 0.25, endAmplitude: 0.95)
            case .holdAfterInhale:
                Segment(duration: spec.duration, startCutoff: high, endCutoff: high,
                        startAmplitude: holdAmplitude, endAmplitude: holdAmplitude)
            case .exhale:
                Segment(duration: spec.duration, startCutoff: high, endCutoff: low,
                        startAmplitude: 0.85, endAmplitude: 0.2)
            case .holdAfterExhale:
                Segment(duration: spec.duration, startCutoff: low, endCutoff: low,
                        startAmplitude: holdAmplitude, endAmplitude: holdAmplitude)
            }
        }
        return OceanProgram(segments: segments, timbre: timbre)
    }

    /// Steady distant surf (or breeze) for the meditation timer.
    static func ambient(timbre: Timbre = .surf) -> OceanProgram {
        let cutoff = timbre == .surf ? 650.0 : 1200.0
        return OceanProgram(
            segments: [
                Segment(duration: 60, startCutoff: cutoff, endCutoff: cutoff,
                        startAmplitude: 0.35, endAmplitude: 0.35)
            ],
            timbre: timbre
        )
    }

    /// Surf parameters at `time` seconds since program start. Wraps around the cycle.
    func value(at time: TimeInterval) -> (cutoff: Double, amplitude: Double) {
        let cycle = cycleDuration
        guard cycle > 0, time >= 0, let last = segments.last else {
            return (Self.lowCutoff, 0)
        }
        var offset = time.truncatingRemainder(dividingBy: cycle)
        for segment in segments {
            if offset < segment.duration {
                let progress = offset / segment.duration
                return (
                    segment.startCutoff + (segment.endCutoff - segment.startCutoff) * progress,
                    segment.startAmplitude + (segment.endAmplitude - segment.startAmplitude) * progress
                )
            }
            offset -= segment.duration
        }
        return (last.endCutoff, last.endAmplitude)
    }
}
