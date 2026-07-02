import Foundation
import Testing
@testable import Breathwave

struct MotionBreathDetectorTests {
    private static let sampleRate = 50.0

    /// Feeds precomputed samples through a fresh detector.
    private func run(_ values: [Double]) -> [MotionBreathDetector.Reading] {
        var detector = MotionBreathDetector()
        return values.enumerated().map { index, value in
            detector.process(value: value, at: Double(index) / Self.sampleRate)
        }
    }

    /// Sine "breath" around a gravity-like offset: frequency in Hz, amplitude in g.
    private func sineBreath(seconds: Double, frequency: Double, amplitude: Double = 0.01) -> [Double] {
        (0..<Int(seconds * Self.sampleRate)).map { index in
            let t = Double(index) / Self.sampleRate
            return 1.0 + amplitude * sin(2 * .pi * frequency * t)
        }
    }

    @Test func steadySineReadsAsTwelveBreathsPerMinute() throws {
        let readings = run(sineBreath(seconds: 90, frequency: 0.2))
        let last = try #require(readings.last)
        let bpm = try #require(last.breathsPerMinute)
        #expect(bpm > 10.5 && bpm < 13.5)
        #expect(last.hasSignal)
    }

    @Test func steadySineScoresHighSteadiness() throws {
        let readings = run(sineBreath(seconds: 120, frequency: 0.2))
        let steadiness = try #require(readings.last?.steadiness)
        #expect(steadiness > 0.7)
    }

    @Test func levelSweepsTheFullBreathRange() {
        let readings = run(sineBreath(seconds: 90, frequency: 0.2))
        // Once settled, the level should visit both ends of the range.
        let settled = readings.suffix(Int(30 * Self.sampleRate)).map(\.level)
        #expect((settled.max() ?? 0) > 0.8)
        #expect((settled.min() ?? 1) < 0.2)
    }

    @Test func stillnessIsNotMistakenForBreath() {
        // Fast tremor far above the breathing band, tiny amplitude.
        let values = (0..<Int(60 * Self.sampleRate)).map { index in
            1.0 + 0.0002 * sin(2 * .pi * 8 * Double(index) / Self.sampleRate)
        }
        let readings = run(values)
        #expect(readings.last?.breathsPerMinute == nil)
        #expect(readings.last?.hasSignal == false)
    }

    @Test func irregularRhythmScoresLowerThanRegular() throws {
        // Periods jump around 3...8 s, cycle by cycle.
        var random = BloomParameters.SplitMix64(seed: 7)
        var phase = 0.0
        var period = 4.0
        let irregular = (0..<Int(120 * Self.sampleRate)).map { _ in
            phase += 2 * .pi / (period * Self.sampleRate)
            if phase > 2 * .pi {
                phase -= 2 * .pi
                period = 3 + random.unit() * 5
            }
            return 1.0 + 0.01 * sin(phase)
        }
        let irregularScore = try #require(run(irregular).last?.steadiness)
        let regularScore = try #require(run(sineBreath(seconds: 120, frequency: 0.2)).last?.steadiness)
        #expect(irregularScore < regularScore)
    }

    @Test func repeatedTimestampsLeaveTheStateUntouched() {
        var detector = MotionBreathDetector()
        _ = detector.process(value: 1.0, at: 0)
        let first = detector.process(value: 1.01, at: 0.02)
        let repeated = detector.process(value: 5.0, at: 0.02)
        #expect(first == repeated)
    }
}
