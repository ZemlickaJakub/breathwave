import Foundation

/// Pure, sample-rate-independent description of the breathing soundtrack:
/// the tone rises with the inhale, falls with the exhale, holds are silent.
/// `value(at:)` runs on the realtime audio thread — keep it allocation-free.
struct ToneProgram: Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        var duration: TimeInterval
        var startFrequency: Double
        var endFrequency: Double
        /// Target amplitude 0...1; 0 keeps the segment silent (holds).
        var amplitude: Double
    }

    var segments: [Segment]

    var cycleDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Frequency glide range for breathing tones (G3 → G4, one octave).
    static let lowFrequency: Double = 196
    static let highFrequency: Double = 392
    static let breathingAmplitude: Double = 0.4

    static func breathing(_ breathingProtocol: BreathingProtocol) -> ToneProgram {
        let segments = breathingProtocol.phases.map { spec -> Segment in
            switch spec.phase {
            case .inhale:
                Segment(duration: spec.duration, startFrequency: lowFrequency,
                        endFrequency: highFrequency, amplitude: breathingAmplitude)
            case .holdAfterInhale:
                Segment(duration: spec.duration, startFrequency: highFrequency,
                        endFrequency: highFrequency, amplitude: 0)
            case .exhale:
                Segment(duration: spec.duration, startFrequency: highFrequency,
                        endFrequency: lowFrequency, amplitude: breathingAmplitude)
            case .holdAfterExhale:
                Segment(duration: spec.duration, startFrequency: lowFrequency,
                        endFrequency: lowFrequency, amplitude: 0)
            }
        }
        return ToneProgram(segments: segments)
    }

    /// Tone parameters at `time` seconds since program start. Wraps around the cycle.
    func value(at time: TimeInterval) -> (frequency: Double, amplitude: Double) {
        let cycle = cycleDuration
        guard cycle > 0, time >= 0, let last = segments.last else {
            return (Self.lowFrequency, 0)
        }
        var offset = time.truncatingRemainder(dividingBy: cycle)
        for segment in segments {
            if offset < segment.duration {
                let progress = offset / segment.duration
                let frequency = segment.startFrequency
                    + (segment.endFrequency - segment.startFrequency) * progress
                // Short ease-in/out inside each segment avoids abrupt onsets.
                let fade = min(0.25, segment.duration / 4)
                let envelope = fade > 0
                    ? max(0, min(1, offset / fade, (segment.duration - offset) / fade))
                    : 1
                return (frequency, segment.amplitude * envelope)
            }
            offset -= segment.duration
        }
        return (last.endFrequency, 0)
    }
}
