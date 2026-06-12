import Foundation
import Observation

/// Single source of truth for a running breathing session.
/// Phase timing is derived from absolute time (`CFAbsoluteTimeGetCurrent`),
/// never accumulated from timer ticks, so it cannot drift.
@MainActor
@Observable
final class BreathingEngine {
    enum State: Equatable {
        case idle
        case running
        case paused
        case finished
    }

    /// Where in the breathing cycle the session is at a given moment.
    struct Snapshot: Equatable {
        var phase: BreathPhase
        /// 0...1 within the current phase.
        var phaseProgress: Double
        var phaseRemaining: TimeInterval
        /// Completed-cycle count, starts at 0.
        var cycleIndex: Int
        var elapsed: TimeInterval
        /// nil for open-ended sessions.
        var remaining: TimeInterval?
    }

    private(set) var state: State = .idle
    private(set) var activeProtocol: BreathingProtocol?
    /// Planned session length in seconds; nil means open-ended.
    private(set) var plannedDuration: TimeInterval?

    @ObservationIgnored private let now: @MainActor () -> TimeInterval
    /// Absolute time of the last (re)start.
    @ObservationIgnored private var startReference: TimeInterval = 0
    /// Practice time gathered before the last pause.
    @ObservationIgnored private var accumulated: TimeInterval = 0

    init(now: @escaping @MainActor () -> TimeInterval = { CFAbsoluteTimeGetCurrent() }) {
        self.now = now
    }

    /// Elapsed practice time, clamped to the planned duration.
    var elapsed: TimeInterval {
        switch state {
        case .idle:
            return 0
        case .running:
            return min(accumulated + (now() - startReference), plannedDuration ?? .infinity)
        case .paused, .finished:
            return accumulated
        }
    }

    func start(_ breathingProtocol: BreathingProtocol, duration: TimeInterval? = nil) {
        guard breathingProtocol.cycleDuration > 0 else { return }
        activeProtocol = breathingProtocol
        plannedDuration = duration
        accumulated = 0
        startReference = now()
        state = .running
    }

    func pause() {
        guard state == .running else { return }
        accumulated = elapsed
        state = .paused
    }

    func resume() {
        guard state == .paused else { return }
        startReference = now()
        state = .running
    }

    /// Ends the session early, keeping the elapsed time (user taps End).
    func finish() {
        guard state == .running || state == .paused else { return }
        accumulated = elapsed
        state = .finished
    }

    /// Discards the session and returns to idle.
    func reset() {
        state = .idle
        activeProtocol = nil
        plannedDuration = nil
        accumulated = 0
    }

    /// Advances the state machine; flips to `.finished` once the planned
    /// duration is reached. Call from the render loop (TimelineView).
    func tick() {
        guard state == .running, let plannedDuration else { return }
        if accumulated + (now() - startReference) >= plannedDuration {
            accumulated = plannedDuration
            state = .finished
        }
    }

    /// Current position in the breathing cycle; nil when idle.
    var snapshot: Snapshot? {
        guard let activeProtocol, state != .idle else { return nil }
        let elapsed = self.elapsed
        guard let position = Self.position(atElapsed: elapsed, in: activeProtocol) else { return nil }
        return Snapshot(
            phase: position.phase,
            phaseProgress: position.progress,
            phaseRemaining: position.duration - position.elapsedInPhase,
            cycleIndex: position.cycleIndex,
            elapsed: elapsed,
            remaining: plannedDuration.map { max(0, $0 - elapsed) }
        )
    }
}

extension BreathingEngine {
    struct PhasePosition: Equatable, Sendable {
        var phase: BreathPhase
        var progress: Double
        var elapsedInPhase: TimeInterval
        var duration: TimeInterval
        var cycleIndex: Int
    }

    /// Pure mapping from elapsed time to a position in the protocol's cycle.
    nonisolated static func position(
        atElapsed elapsed: TimeInterval,
        in breathingProtocol: BreathingProtocol
    ) -> PhasePosition? {
        let cycle = breathingProtocol.cycleDuration
        let phases = breathingProtocol.phases
        guard cycle > 0, elapsed >= 0, let lastPhase = phases.last else { return nil }

        let cycleIndex = Int(elapsed / cycle)
        var offset = elapsed.truncatingRemainder(dividingBy: cycle)
        for spec in phases {
            if offset < spec.duration {
                return PhasePosition(
                    phase: spec.phase,
                    progress: offset / spec.duration,
                    elapsedInPhase: offset,
                    duration: spec.duration,
                    cycleIndex: cycleIndex
                )
            }
            offset -= spec.duration
        }
        // Floating-point edge: treat as the very end of the last phase.
        return PhasePosition(
            phase: lastPhase.phase,
            progress: 1,
            elapsedInPhase: lastPhase.duration,
            duration: lastPhase.duration,
            cycleIndex: cycleIndex
        )
    }
}
