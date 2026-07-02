import Foundation

/// Pure signal processing that turns raw motion samples into a live breath
/// trace. The phone lies flat on the belly and its slow tilt follows the
/// breath; the gravity z-component is the input. No CoreMotion in here,
/// so tests can feed synthetic signals.
struct MotionBreathDetector {
    struct Reading: Equatable {
        /// Normalized breath position: 0 empty lungs, 1 full.
        var level: Double
        /// True once the swing is large enough to be a breath, not noise.
        var hasSignal: Bool
        /// True while the belly is rising (inhale).
        var isRising: Bool
        /// nil until a full breath cycle has been seen.
        var breathsPerMinute: Double?
        /// Rhythm regularity 0...1; nil until three breaths are in.
        var steadiness: Double?
    }

    /// Baseline drift filter — everything slower than this is posture, not breath.
    private static let baselineTau = 10.0
    /// Noise smoothing — everything faster than this is tremor, not breath.
    private static let smoothingTau = 0.4
    /// Envelope release; adapts the turn threshold to the breath depth.
    private static let envelopeTau = 20.0
    /// Swings smaller than this are stillness, not breath (in g).
    private static let minimumAmplitude = 0.0015
    /// Fraction of the recent swing needed to confirm a turn-around.
    private static let turnFraction = 0.25
    /// Plausible breath periods; anything outside is ignored (2...40 bpm).
    private static let periodRange = 1.5...30.0
    private static let periodWindow = 5

    private var smoothed: Double?
    private var baseline = 0.0
    private var lastTime: TimeInterval?
    private var envelopeMin = 0.0
    private var envelopeMax = 0.0
    private var isRising = true
    private var extremeValue = 0.0
    private var lastInhaleStart: TimeInterval?
    private var periods: [Double] = []

    mutating func process(value: Double, at time: TimeInterval) -> Reading {
        guard let previousSmoothed = smoothed, let previousTime = lastTime else {
            smoothed = value
            baseline = value
            lastTime = time
            return reading(signal: 0)
        }
        let dt = time - previousTime
        guard dt > 0 else { return reading(signal: previousSmoothed - baseline) }
        lastTime = time

        let smoothAlpha = dt / (Self.smoothingTau + dt)
        let current = previousSmoothed + smoothAlpha * (value - previousSmoothed)
        smoothed = current
        let baselineAlpha = dt / (Self.baselineTau + dt)
        baseline += baselineAlpha * (current - baseline)
        let signal = current - baseline

        let envelopeAlpha = dt / (Self.envelopeTau + dt)
        envelopeMax = max(signal, envelopeMax + envelopeAlpha * (signal - envelopeMax))
        envelopeMin = min(signal, envelopeMin + envelopeAlpha * (signal - envelopeMin))

        trackTurns(signal: signal, at: time)
        return reading(signal: signal)
    }

    private mutating func trackTurns(signal: Double, at time: TimeInterval) {
        let threshold = max((envelopeMax - envelopeMin) * Self.turnFraction, Self.minimumAmplitude)
        if isRising {
            if signal > extremeValue {
                extremeValue = signal
            } else if extremeValue - signal > threshold {
                // Past the peak: the exhale has begun.
                isRising = false
                extremeValue = signal
            }
        } else {
            if signal < extremeValue {
                extremeValue = signal
            } else if signal - extremeValue > threshold {
                // Past the trough: a new inhale has begun.
                isRising = true
                extremeValue = signal
                registerInhaleStart(at: time)
            }
        }
    }

    private mutating func registerInhaleStart(at time: TimeInterval) {
        defer { lastInhaleStart = time }
        guard let lastInhaleStart else { return }
        let period = time - lastInhaleStart
        guard Self.periodRange.contains(period) else { return }
        periods.append(period)
        if periods.count > Self.periodWindow {
            periods.removeFirst()
        }
    }

    private func reading(signal: Double) -> Reading {
        let amplitude = envelopeMax - envelopeMin
        let hasSignal = amplitude >= Self.minimumAmplitude
        let level = hasSignal
            ? min(1, max(0, (signal - envelopeMin) / amplitude))
            : 0.5
        return Reading(
            level: level,
            hasSignal: hasSignal,
            isRising: isRising,
            breathsPerMinute: breathsPerMinute,
            steadiness: steadiness
        )
    }

    private var breathsPerMinute: Double? {
        guard !periods.isEmpty else { return nil }
        return 60 / (periods.reduce(0, +) / Double(periods.count))
    }

    /// 1 for a perfectly even rhythm, falling toward 0 as periods scatter.
    private var steadiness: Double? {
        guard periods.count >= 3 else { return nil }
        let mean = periods.reduce(0, +) / Double(periods.count)
        let variance = periods.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(periods.count)
        let variation = (variance.squareRoot()) / mean
        return min(1, max(0, 1 - variation * 2))
    }
}
