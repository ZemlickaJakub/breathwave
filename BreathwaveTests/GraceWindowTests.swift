import Foundation
import Testing
@testable import Breathwave

/// The monitor must not re-shield while a grace window opened past the shield
/// is still live; otherwise a stray callback forces a second pass.
struct GraceWindowTests {
    private let relockAt: TimeInterval = 1_800_000_000

    private func at(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: relockAt + offset)
    }

    @Test func noMarkerMeansNoGraceWindow() {
        #expect(!FocusShared.isInGraceWindow(relockAt: 0, now: at(-600)))
    }

    @Test func liveWindowBlocksRelock() {
        #expect(FocusShared.isInGraceWindow(relockAt: relockAt, now: at(-300)))
        #expect(FocusShared.isInGraceWindow(relockAt: relockAt, now: at(-31)))
    }

    // Small tolerance for scheduling jitter: the scheduled re-lock callback may
    // arrive a little early and must still re-shield.
    @Test func relockAllowedWithinToleranceOfDeadline() {
        #expect(!FocusShared.isInGraceWindow(relockAt: relockAt, now: at(-30)))
        #expect(!FocusShared.isInGraceWindow(relockAt: relockAt, now: at(-10)))
    }

    @Test func relockAllowedAfterDeadline() {
        #expect(!FocusShared.isInGraceWindow(relockAt: relockAt, now: at(0)))
        #expect(!FocusShared.isInGraceWindow(relockAt: relockAt, now: at(3600)))
    }
}
