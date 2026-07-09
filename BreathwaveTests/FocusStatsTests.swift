import Foundation
import Testing
@testable import Breathwave

struct FocusStatsTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0
    ) -> Date {
        Self.utc.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    private func event(
        _ kind: FocusEvent.Kind,
        at date: Date,
        grantedMinutes: Int? = nil
    ) -> FocusEvent {
        FocusEvent(date: date, kind: kind, grantedMinutes: grantedMinutes)
    }

    private func stats(_ events: [FocusEvent], asOf reference: Date) -> FocusStats {
        FocusStats(events: events, asOf: reference, calendar: Self.utc)
    }

    // MARK: - Today vs other days

    @Test func todayCountsOnlyTheReferenceDay() {
        let reference = date(2026, 6, 15, 18)
        let s = stats([
            event(.resisted, at: date(2026, 6, 15, 8)),
            event(.resisted, at: date(2026, 6, 15, 9)),
            event(.opened, at: date(2026, 6, 15, 10)),
            event(.resisted, at: date(2026, 6, 14, 23, 59)),   // yesterday
            event(.opened, at: date(2026, 6, 16, 0, 1)),        // tomorrow
        ], asOf: reference)
        #expect(s.todayResisted == 2)
        #expect(s.todayOpened == 1)
    }

    @Test func emptyHistoryHasZeroToday() {
        let s = stats([], asOf: date(2026, 6, 15))
        #expect(s.todayResisted == 0)
        #expect(s.todayOpened == 0)
    }

    // MARK: - Lifetime totals

    @Test func totalsCountEveryDay() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 1)),
            event(.resisted, at: date(2026, 6, 10)),
            event(.resisted, at: date(2026, 6, 15)),
            event(.opened, at: date(2026, 6, 12)),
        ], asOf: date(2026, 6, 15))
        #expect(s.totalResisted == 3)
        #expect(s.totalOpened == 1)
    }

    @Test func totalGrantedMinutesSumsOpenedEvents() {
        let s = stats([
            event(.opened, at: date(2026, 6, 15, 8), grantedMinutes: 5),
            event(.opened, at: date(2026, 6, 15, 9), grantedMinutes: 15),
            event(.resisted, at: date(2026, 6, 15, 10)),   // nil, ignored
        ], asOf: date(2026, 6, 15))
        #expect(s.totalGrantedMinutes == 20)
    }

    // MARK: - Resist rate (last 7 days)

    @Test func resistRateIsZeroWithNoEvents() {
        let s = stats([], asOf: date(2026, 6, 15))
        #expect(s.resistRate == 0)
    }

    @Test func resistRateIsResistedOverTotal() {
        // 3 resisted, 1 opened within the window -> 0.75
        let s = stats([
            event(.resisted, at: date(2026, 6, 13)),
            event(.resisted, at: date(2026, 6, 14)),
            event(.resisted, at: date(2026, 6, 15, 8)),
            event(.opened, at: date(2026, 6, 15, 9)),
        ], asOf: date(2026, 6, 15))
        #expect(s.resistRate == 0.75)
    }

    @Test func resistRateIgnoresEventsOlderThanSevenDays() {
        // Reference 2026-06-15; window is 06-09...06-15 inclusive.
        let s = stats([
            event(.opened, at: date(2026, 6, 8)),      // 8 days back, excluded
            event(.opened, at: date(2026, 6, 7)),      // excluded
            event(.resisted, at: date(2026, 6, 15)),   // included
        ], asOf: date(2026, 6, 15))
        #expect(s.resistRate == 1.0)
    }

    @Test func resistRateIncludesTheSeventhDayBoundary() {
        // 06-09 is exactly 6 days before 06-15 -> still in the 7-day window.
        let s = stats([
            event(.opened, at: date(2026, 6, 9)),
        ], asOf: date(2026, 6, 15))
        #expect(s.resistRate == 0.0)
    }

    // MARK: - Streak

    @Test func streakCountsLeadingResistedEvents() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 13)),
            event(.resisted, at: date(2026, 6, 14)),
            event(.resisted, at: date(2026, 6, 15)),
        ], asOf: date(2026, 6, 15))
        #expect(s.currentResistStreak == 3)
    }

    @Test func streakBreaksOnMostRecentOpened() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 13)),
            event(.resisted, at: date(2026, 6, 14)),
            event(.opened, at: date(2026, 6, 15)),   // most recent -> streak 0
        ], asOf: date(2026, 6, 15))
        #expect(s.currentResistStreak == 0)
    }

    @Test func streakStopsAtAnEarlierOpened() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 11)),
            event(.opened, at: date(2026, 6, 12)),
            event(.resisted, at: date(2026, 6, 13)),
            event(.resisted, at: date(2026, 6, 14)),
        ], asOf: date(2026, 6, 15))
        #expect(s.currentResistStreak == 2)
    }

    @Test func streakUsesChronologyNotArrayOrder() {
        // Deliberately shuffled input; ordering must come from dates.
        let s = stats([
            event(.resisted, at: date(2026, 6, 14)),
            event(.opened, at: date(2026, 6, 12)),
            event(.resisted, at: date(2026, 6, 15)),
            event(.resisted, at: date(2026, 6, 13)),
        ], asOf: date(2026, 6, 15))
        // Most recent three (6/15, 6/14, 6/13) are all resisted; the 6/12 open
        // is oldest and never reached.
        #expect(s.currentResistStreak == 3)
    }

    @Test func emptyHistoryHasZeroStreak() {
        let s = stats([], asOf: date(2026, 6, 15))
        #expect(s.currentResistStreak == 0)
    }

    // MARK: - Daily breakdown

    @Test func dailyFocusIncludesEmptyDaysOldestFirst() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 13, 8)),
            event(.resisted, at: date(2026, 6, 15, 8)),
            event(.opened, at: date(2026, 6, 15, 20)),
        ], asOf: date(2026, 6, 15))

        let daily = s.dailyFocus(lastDays: 7)
        #expect(daily.count == 7)
        // Window 6/9…6/15 (oldest first); resists land on 6/13 (index 4) and 6/15 (index 6).
        #expect(daily.map(\.resisted) == [0, 0, 0, 0, 1, 0, 1])
        #expect(daily.map(\.opened) == [0, 0, 0, 0, 0, 0, 1])
        #expect(daily.first?.day == Self.utc.startOfDay(for: date(2026, 6, 9)))
        #expect(daily.last?.day == Self.utc.startOfDay(for: date(2026, 6, 15)))
    }

    @Test func dailyFocusExcludesEventsOutsideWindow() {
        let s = stats([
            event(.resisted, at: date(2026, 6, 1)),   // far outside 3-day window
            event(.resisted, at: date(2026, 6, 15)),
        ], asOf: date(2026, 6, 15))

        let daily = s.dailyFocus(lastDays: 3)
        #expect(daily.count == 3)
        #expect(daily.map(\.resisted) == [0, 0, 1])
    }
}
