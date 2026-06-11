import Foundation
import Testing
@testable import Breathwave

/// Controllable clock so phase timing can be tested deterministically.
@MainActor
final class FakeClock {
    var time: TimeInterval = 0
}

@MainActor
struct BreathingEngineTests {
    let clock: FakeClock
    let engine: BreathingEngine

    init() {
        let clock = FakeClock()
        self.clock = clock
        self.engine = BreathingEngine(now: { clock.time })
    }

    // MARK: - Phase sequencing

    @Test func boxPhaseSequenceOverTwoCycles() throws {
        engine.start(.box)
        let expectations: [(time: TimeInterval, phase: BreathPhase, cycle: Int)] = [
            (0, .inhale, 0),
            (3.9, .inhale, 0),
            (4, .holdAfterInhale, 0),
            (8, .exhale, 0),
            (12, .holdAfterExhale, 0),
            (15.9, .holdAfterExhale, 0),
            (16, .inhale, 1),
            (28, .holdAfterExhale, 1),
        ]
        for expected in expectations {
            clock.time = expected.time
            let snapshot = try #require(engine.snapshot, "no snapshot at t=\(expected.time)")
            #expect(snapshot.phase == expected.phase, "at t=\(expected.time)")
            #expect(snapshot.cycleIndex == expected.cycle, "at t=\(expected.time)")
        }
    }

    @Test func fourSevenEightWrapsStraightToInhale() throws {
        engine.start(.fourSevenEight)
        clock.time = 18.9
        #expect(try #require(engine.snapshot).phase == .exhale)
        clock.time = 19
        let snapshot = try #require(engine.snapshot)
        #expect(snapshot.phase == .inhale)
        #expect(snapshot.cycleIndex == 1)
        #expect(abs(snapshot.phaseProgress) < 1e-9)
    }

    @Test func phaseProgressIsLinearWithinPhase() throws {
        engine.start(.coherent)
        clock.time = 2.75
        var snapshot = try #require(engine.snapshot)
        #expect(snapshot.phase == .inhale)
        #expect(abs(snapshot.phaseProgress - 0.5) < 1e-9)
        #expect(abs(snapshot.phaseRemaining - 2.75) < 1e-9)

        clock.time = 8.25
        snapshot = try #require(engine.snapshot)
        #expect(snapshot.phase == .exhale)
        #expect(abs(snapshot.phaseProgress - 0.5) < 1e-9)
    }

    // MARK: - Pause / resume

    @Test func pauseFreezesElapsedAndPosition() throws {
        engine.start(.box)
        clock.time = 5
        engine.pause()
        clock.time = 100
        #expect(engine.state == .paused)
        #expect(engine.elapsed == 5)
        let snapshot = try #require(engine.snapshot)
        #expect(snapshot.phase == .holdAfterInhale)
    }

    @Test func resumeContinuesFromPausedPosition() throws {
        engine.start(.box)
        clock.time = 5
        engine.pause()
        clock.time = 100
        engine.resume()
        clock.time = 103
        #expect(engine.elapsed == 8)
        let snapshot = try #require(engine.snapshot)
        #expect(snapshot.phase == .exhale)
        #expect(abs(snapshot.phaseProgress) < 1e-9)
    }

    // MARK: - Session duration

    @Test func tickFinishesSessionAtPlannedDuration() {
        engine.start(.box, duration: 60)
        clock.time = 59.9
        engine.tick()
        #expect(engine.state == .running)

        clock.time = 60.1
        engine.tick()
        #expect(engine.state == .finished)
        #expect(engine.elapsed == 60)
        #expect(engine.snapshot?.remaining == 0)
    }

    @Test func elapsedIsClampedToPlannedDurationEvenBeforeTick() {
        engine.start(.box, duration: 60)
        clock.time = 75
        #expect(engine.elapsed == 60)
    }

    @Test func openEndedSessionNeverAutoFinishes() {
        engine.start(.coherent)
        clock.time = 10_000
        engine.tick()
        #expect(engine.state == .running)
        #expect(engine.snapshot?.remaining == nil)
    }

    @Test func finishEarlyKeepsElapsed() {
        engine.start(.coherent, duration: 300)
        clock.time = 42
        engine.finish()
        #expect(engine.state == .finished)
        #expect(engine.elapsed == 42)
    }

    // MARK: - Lifecycle

    @Test func resetReturnsToIdle() {
        engine.start(.box)
        clock.time = 10
        engine.reset()
        #expect(engine.state == .idle)
        #expect(engine.snapshot == nil)
        #expect(engine.elapsed == 0)
    }

    @Test func startIgnoresProtocolWithZeroCycle() {
        let empty = BreathingProtocol(
            id: "empty", nameKey: "Empty",
            inhale: 0, holdAfterInhale: 0, exhale: 0, holdAfterExhale: 0
        )
        engine.start(empty)
        #expect(engine.state == .idle)
        #expect(engine.snapshot == nil)
    }

    // MARK: - Pure position function

    @Test func positionAtExactCycleBoundaryStartsNextCycle() throws {
        let position = try #require(BreathingEngine.position(atElapsed: 16, in: .box))
        #expect(position.phase == .inhale)
        #expect(position.cycleIndex == 1)
        #expect(abs(position.progress) < 1e-9)
    }

    @Test func positionRejectsNegativeElapsed() {
        #expect(BreathingEngine.position(atElapsed: -1, in: .box) == nil)
    }
}
