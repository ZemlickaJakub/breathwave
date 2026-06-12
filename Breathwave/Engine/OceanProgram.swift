import Foundation

/// Pure, sample-rate-independent description of the ocean soundtrack.
/// The surf swells with the inhale (louder, brighter) and recedes with the
/// exhale; holds are a quiet murmur — the ocean never goes fully silent.
/// `value(at:)` runs on the realtime audio thread — keep it allocation-free.
struct OceanProgram: Equatable, Sendable {
    /// Sound character: surf has a deep rumble, breeze is light and airy,
    /// breath mimics calm human breathing (band-passed air, silent holds).
    enum Timbre: Equatable, Sendable {
        case surf
        case breeze
        case breath
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
    /// Marks the meditation-timer soundtrack; when the bundled ambient
    /// recording is present it replaces this synthesized program.
    var isAmbient = false

    var cycleDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    static let lowCutoff: Double = 320
    static let highCutoff: Double = 1400
    static let holdAmplitude: Double = 0.15

    /// Cutoff range per timbre — breeze stays low and narrow so it washes
    /// gently instead of hissing like a storm; breath opens up as air flows.
    private static func cutoffRange(for timbre: Timbre) -> (low: Double, high: Double) {
        switch timbre {
        case .surf: (lowCutoff, highCutoff)
        case .breeze: (380, 950)
        case .breath: (600, 2400)
        }
    }

    /// Real breath holds are silent; the ocean keeps murmuring.
    private static func holdAmplitude(for timbre: Timbre) -> Double {
        timbre == .breath ? 0.04 : holdAmplitude
    }

    /// Breath-synced surf: the wave builds during the inhale and washes out
    /// during the exhale. Amplitude steps between segments are smoothed by
    /// the renderer's slew, which is what makes the "crash" feel natural.
    static func breathing(_ breathingProtocol: BreathingProtocol, timbre: Timbre = .surf) -> OceanProgram {
        let (low, high) = cutoffRange(for: timbre)
        let holdLevel = holdAmplitude(for: timbre)
        // Breath is not one long sweep (that reads as wind): the inhale is
        // bright air through the nose, the exhale a darker mouth "haa" —
        // two distinct registers. Holds are silent, so the cutoff jump
        // between them is never heard.
        let isBreath = timbre == .breath
        let segments = breathingProtocol.phases.map { spec -> Segment in
            switch spec.phase {
            case .inhale:
                Segment(duration: spec.duration,
                        startCutoff: isBreath ? 1300 : low, endCutoff: high,
                        startAmplitude: 0.25, endAmplitude: 0.95)
            case .holdAfterInhale:
                Segment(duration: spec.duration, startCutoff: high, endCutoff: high,
                        startAmplitude: holdLevel, endAmplitude: holdLevel)
            case .exhale:
                Segment(duration: spec.duration,
                        startCutoff: isBreath ? 950 : high, endCutoff: low,
                        startAmplitude: isBreath ? 0.95 : 0.85,
                        endAmplitude: isBreath ? 0.15 : 0.2)
            case .holdAfterExhale:
                Segment(duration: spec.duration, startCutoff: low, endCutoff: low,
                        startAmplitude: holdLevel, endAmplitude: holdLevel)
            }
        }
        return OceanProgram(segments: segments, timbre: timbre)
    }

    /// Steady distant surf (or breeze) for the meditation timer.
    static func ambient(timbre: Timbre = .surf) -> OceanProgram {
        let cutoff = timbre == .surf ? 650.0 : 800.0
        return OceanProgram(
            segments: [
                Segment(duration: 60, startCutoff: cutoff, endCutoff: cutoff,
                        startAmplitude: 0.35, endAmplitude: 0.35)
            ],
            timbre: timbre,
            isAmbient: true
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
