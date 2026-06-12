import Foundation
import Testing
@testable import Breathwave

@MainActor
struct SessionStoreTests {
    static let prague: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Prague")!
        return calendar
    }()

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "breathwave-tests-\(UUID().uuidString).json")
    }

    private func date(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        in calendar: Calendar = SessionStoreTests.prague
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func session(at date: Date, duration: TimeInterval = 300) -> Session {
        Session(completedAt: date, duration: duration, kind: .meditation)
    }

    // MARK: - Persistence

    @Test func persistenceRoundtrip() {
        let url = makeStoreURL()
        let store = SessionStore(fileURL: url, calendar: Self.prague)
        let first = session(at: date(2026, 6, 10))
        let second = Session(
            completedAt: date(2026, 6, 11),
            duration: 330,
            kind: .breathing(protocolID: "box")
        )
        store.add(first)
        store.add(second)

        let reloaded = SessionStore(fileURL: url, calendar: Self.prague)
        #expect(reloaded.sessions == [first, second])
    }

    @Test func corruptFileLoadsAsEmpty() throws {
        let url = makeStoreURL()
        try Data("not json at all".utf8).write(to: url)
        let store = SessionStore(fileURL: url, calendar: Self.prague)
        #expect(store.sessions.isEmpty)
    }

    @Test func totalDurationSumsAllSessions() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 10), duration: 300))
        store.add(session(at: date(2026, 6, 11), duration: 600))
        #expect(store.totalDuration == 900)
    }

    // MARK: - Streak

    @Test func emptyStoreHasZeroStreak() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 0)
    }

    @Test func consecutiveDaysCount() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 9)))
        store.add(session(at: date(2026, 6, 10)))
        store.add(session(at: date(2026, 6, 11)))
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 3)
    }

    @Test func multipleSessionsOnSameDayCountOnce() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 11, 8)))
        store.add(session(at: date(2026, 6, 11, 20)))
        #expect(store.currentStreak(asOf: date(2026, 6, 11, 21)) == 1)
    }

    @Test func streakSurvivesUntilEndOfCurrentDay() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 10)))
        // No session today yet — yesterday's streak still counts.
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 1)
    }

    @Test func streakIsZeroAfterAFullMissedDay() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 9)))
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 0)
    }

    @Test func gapResetsStreak() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 7)))
        store.add(session(at: date(2026, 6, 8)))
        store.add(session(at: date(2026, 6, 11)))
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 1)
    }

    // MARK: - Day boundaries

    @Test func sessionsJustAroundMidnightFallOnDifferentDays() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 10, 23, 59)))
        store.add(session(at: date(2026, 6, 11, 0, 1)))
        #expect(store.currentStreak(asOf: date(2026, 6, 11)) == 2)
    }

    @Test func streakCrossesMonthBoundary() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 5, 31)))
        store.add(session(at: date(2026, 6, 1)))
        #expect(store.currentStreak(asOf: date(2026, 6, 1)) == 2)
    }

    // MARK: - Daily minutes (chart data)

    @Test func dailyMinutesIncludesEmptyDaysOldestFirst() {
        let store = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        store.add(session(at: date(2026, 6, 9), duration: 300))
        store.add(session(at: date(2026, 6, 11, 8), duration: 120))
        store.add(session(at: date(2026, 6, 11, 20), duration: 180))

        let daily = store.dailyMinutes(lastDays: 7, asOf: date(2026, 6, 11))
        #expect(daily.count == 7)
        #expect(daily.map(\.minutes) == [0, 0, 0, 0, 5, 0, 5])
        #expect(daily.last?.day == Self.prague.startOfDay(for: date(2026, 6, 11)))
    }

    @Test func calendarTimeZoneControlsDayBucketing() {
        // Two sessions two hours apart, straddling midnight UTC:
        // 23:00 UTC June 10 and 01:00 UTC June 11. In Prague (UTC+2, summer)
        // both fall on June 11, so the same data yields a different streak.
        let first = session(at: date(2026, 6, 10, 23, 0, in: Self.utc))
        let second = session(at: date(2026, 6, 11, 1, 0, in: Self.utc))
        let reference = date(2026, 6, 11, 12, 0, in: Self.utc)

        let utcStore = SessionStore(fileURL: makeStoreURL(), calendar: Self.utc)
        utcStore.add(first)
        utcStore.add(second)
        #expect(utcStore.currentStreak(asOf: reference) == 2)

        let pragueStore = SessionStore(fileURL: makeStoreURL(), calendar: Self.prague)
        pragueStore.add(first)
        pragueStore.add(second)
        #expect(pragueStore.currentStreak(asOf: reference) == 1)
    }
}
