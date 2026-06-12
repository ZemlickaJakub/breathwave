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
    static let omAmplitude: Double = 0.95

    /// Voiced "om" through the exhale, silence elsewhere. The exhale is
    /// shaped to give the lungs room on both ends: a short silent delay
    /// (settle after the inhale), a slow swell-in, the sustain, and a
    /// release that fades out before the exhale ends — so the next inhale
    /// never lands mid-om.
    static func om(_ breathingProtocol: BreathingProtocol) -> DroneProgram {
        var segments: [Segment] = []
        for spec in breathingProtocol.phases {
            if spec.phase == .exhale {
                let delay = min(0.8, spec.duration * 0.1)
                let rise = min(2.5, spec.duration * 0.25)
                let release = min(1.5, spec.duration * 0.15)
                let sustain = spec.duration - delay - rise - release
                segments.append(Segment(duration: delay, frequency: omFrequency,
                                        startAmplitude: 0, endAmplitude: 0))
                segments.append(Segment(duration: rise, frequency: omFrequency,
                                        startAmplitude: 0, endAmplitude: omAmplitude))
                segments.append(Segment(duration: sustain, frequency: omFrequency,
                                        startAmplitude: omAmplitude, endAmplitude: omAmplitude * 0.9))
                segments.append(Segment(duration: release, frequency: omFrequency,
                                        startAmplitude: omAmplitude * 0.9, endAmplitude: 0))
            } else {
                segments.append(Segment(duration: spec.duration, frequency: omFrequency,
                                        startAmplitude: 0, endAmplitude: 0))
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
