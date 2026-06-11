import Foundation

/// Pure description of the om-training drone: a low voiced tone the user
/// hums along with, sounding only during the exhale.
/// `value(at:)` runs on the realtime audio thread — keep it allocation-free.
struct DroneProgram: Equatable, Sendable {
    struct Segment: Equatable, Sendable {
        var duration: TimeInterval
        var frequency: Double
        var startAmplitude: Double
        var endAmplitude: Double
    }

    var segments: [Segment]

    var cycleDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Comfortable humming pitch (~C3) for most voices.
    static let omFrequency: Double = 130
    static let omAmplitude: Double = 0.32

    /// Voiced "om" through the exhale, silence elsewhere; the renderer's
    /// amplitude slew shapes the soft on/offsets.
    static func om(_ breathingProtocol: BreathingProtocol) -> DroneProgram {
        let segments = breathingProtocol.phases.map { spec -> Segment in
            if spec.phase == .exhale {
                Segment(duration: spec.duration, frequency: omFrequency,
                        startAmplitude: omAmplitude, endAmplitude: omAmplitude * 0.85)
            } else {
                Segment(duration: spec.duration, frequency: omFrequency,
                        startAmplitude: 0, endAmplitude: 0)
            }
        }
        return DroneProgram(segments: segments)
    }

    /// Drone parameters at `time` seconds since program start. Wraps around the cycle.
    func value(at time: TimeInterval) -> (frequency: Double, amplitude: Double) {
        let cycle = cycleDuration
        guard cycle > 0, time >= 0, let last = segments.last else {
            return (Self.omFrequency, 0)
        }
        var offset = time.truncatingRemainder(dividingBy: cycle)
        for segment in segments {
            if offset < segment.duration {
                let progress = offset / segment.duration
                return (
                    segment.frequency,
                    segment.startAmplitude + (segment.endAmplitude - segment.startAmplitude) * progress
                )
            }
            offset -= segment.duration
        }
        return (last.frequency, last.endAmplitude)
    }
}
