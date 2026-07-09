import Foundation
import Testing
@testable import Breathwave

struct FocusBadgesTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    static let reference = FocusBadgesTests.utc.date(
        from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)
    )!

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func earned(_ events: [FocusEvent]) -> Set<String> {
        FocusBadges.earned(from: events, asOf: Self.reference, calendar: Self.utc)
    }

    /// `count` resisted events spread across distinct recent days ending on the
    /// reference day, so they land inside the 7-day window when few and simply
    /// accumulate as lifetime totals when many.
    private func resistedRun(_ count: Int) -> [FocusEvent] {
        (0..<count).map { i in
            FocusEvent(
                date: Self.utc.date(byAdding: .minute, value: -i, to: Self.reference)!,
                kind: .resisted
            )
        }
    }

    // MARK: - Catalog integrity

    @Test func catalogHasUniqueIDs() {
        let ids = FocusBadges.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func statusCoversTheWholeCatalog() {
        let status = FocusBadges.status(from: [], asOf: Self.reference, calendar: Self.utc)
        #expect(status.count == FocusBadges.catalog.count)
        #expect(status.allSatisfy { !$0.isEarned })   // nothing earned from empty history
    }

    // MARK: - Lifetime resist thresholds

    @Test func firstResistJustBelowAndAt() {
        #expect(!earned([FocusEvent(date: Self.reference, kind: .opened)]).contains("first_resist"))
        #expect(earned(resistedRun(1)).contains("first_resist"))
    }

    @Test func tenResistsJustBelowAndAt() {
        #expect(!earned(resistedRun(9)).contains("resist_10"))
        #expect(earned(resistedRun(10)).contains("resist_10"))
    }

    @Test func fiftyResistsJustBelowAndAt() {
        #expect(!earned(resistedRun(49)).contains("resist_50"))
        #expect(earned(resistedRun(50)).contains("resist_50"))
    }

    @Test func hundredResistsJustBelowAndAt() {
        #expect(!earned(resistedRun(99)).contains("resist_100"))
        #expect(earned(resistedRun(100)).contains("resist_100"))
    }

    // MARK: - Streak badge

    @Test func streakBadgeJustBelowAndAt() {
        // Six resisted in a row, preceded by an opened -> streak 6, not earned.
        let sixThenOpen = resistedRun(6) + [
            FocusEvent(date: date(2026, 6, 8), kind: .opened)
        ]
        #expect(!earned(sixThenOpen).contains("streak_7"))

        let sevenThenOpen = resistedRun(7) + [
            FocusEvent(date: date(2026, 6, 8), kind: .opened)
        ]
        #expect(earned(sevenThenOpen).contains("streak_7"))
    }

    @Test func streakBadgeBrokenByRecentOpen() {
        // Seven resisted but the newest event is an open -> streak 0.
        let events = resistedRun(7) + [
            FocusEvent(
                date: Self.utc.date(byAdding: .minute, value: 1, to: Self.reference)!,
                kind: .opened
            )
        ]
        #expect(!earned(events).contains("streak_7"))
    }

    // MARK: - Clean day badge

    @Test func cleanDayEarnedWhenADayHasNoOpens() {
        let events = [
            FocusEvent(date: date(2026, 6, 15, 8), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 9), kind: .resisted),
        ]
        #expect(earned(events).contains("clean_day"))
    }

    @Test func cleanDayNotEarnedWhenEveryResistDayAlsoOpened() {
        let events = [
            FocusEvent(date: date(2026, 6, 15, 8), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 9), kind: .opened),
        ]
        #expect(!earned(events).contains("clean_day"))
    }

    @Test func cleanDayNotEarnedFromEmptyHistory() {
        #expect(!earned([]).contains("clean_day"))
    }

    // MARK: - Weekly resist-rate badge

    @Test func rateBadgeEarnedAtEightyPercentWithEnoughSamples() {
        // 4 resisted + 1 opened = 5 encounters, rate 0.80.
        let events = [
            FocusEvent(date: date(2026, 6, 12), kind: .opened),
            FocusEvent(date: date(2026, 6, 13), kind: .resisted),
            FocusEvent(date: date(2026, 6, 14), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 8), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 9), kind: .resisted),
        ]
        #expect(earned(events).contains("rate_80"))
    }

    @Test func rateBadgeNotEarnedBelowEightyPercent() {
        // 3 resisted + 2 opened = 5 encounters, rate 0.60.
        let events = [
            FocusEvent(date: date(2026, 6, 12), kind: .opened),
            FocusEvent(date: date(2026, 6, 13), kind: .opened),
            FocusEvent(date: date(2026, 6, 14), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 8), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15, 9), kind: .resisted),
        ]
        #expect(!earned(events).contains("rate_80"))
    }

    @Test func rateBadgeNotEarnedBelowSampleFloor() {
        // Perfect 100% rate but only 4 encounters -> below the 5-sample floor.
        let events = [
            FocusEvent(date: date(2026, 6, 12), kind: .resisted),
            FocusEvent(date: date(2026, 6, 13), kind: .resisted),
            FocusEvent(date: date(2026, 6, 14), kind: .resisted),
            FocusEvent(date: date(2026, 6, 15), kind: .resisted),
        ]
        #expect(!earned(events).contains("rate_80"))
    }

    @Test func rateBadgeIgnoresOldEventsForSampleCount() {
        // 5 resisted but all older than 7 days -> window empty, badge not earned.
        let events = (0..<5).map { i in
            FocusEvent(date: date(2026, 5, 1, 12, i), kind: .resisted)
        }
        #expect(!earned(events).contains("rate_80"))
    }
}
