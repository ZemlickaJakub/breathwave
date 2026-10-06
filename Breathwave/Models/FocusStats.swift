import Foundation

/// Motivating statistics derived from Mindful Pause shield events.
///
/// Pure value type: it operates only on the injected `[FocusEvent]` array and
/// never touches UserDefaults or the filesystem — the parent wires persistence.
/// Deterministic and testable via the injected `reference` date and `calendar`.
struct FocusStats: Equatable, Sendable {
    /// Rolling window (in days) used for the weekly resist rate and charts.
    static let weekWindow = 7

    private let events: [FocusEvent]
    private let reference: Date
    private let calendar: Calendar

    init(events: [FocusEvent], asOf reference: Date = .now, calendar: Calendar = .current) {
        self.events = events
        self.reference = reference
        self.calendar = calendar
    }

    // MARK: - Today

    var todayResisted: Int { countToday(.resisted) }
    var todayOpened: Int { countToday(.opened) }

    private func countToday(_ kind: FocusEvent.Kind) -> Int {
        let today = calendar.startOfDay(for: reference)
        return events.filter {
            $0.kind == kind && calendar.startOfDay(for: $0.date) == today
        }.count
    }

    // MARK: - Lifetime totals

    var totalResisted: Int { events.filter { $0.kind == .resisted }.count }
    var totalOpened: Int { events.filter { $0.kind == .opened }.count }

    /// Sum of `grantedMinutes` across every `.opened` event.
    var totalGrantedMinutes: Int {
        events.reduce(0) { $0 + ($1.grantedMinutes ?? 0) }
    }

    // MARK: - Resist rate (last 7 days)

    /// Fraction of shield encounters resisted over the last `weekWindow` days,
    /// defined as resisted / (resisted + opened). Returns 0 when there are no
    /// events in the window (avoids dividing by zero).
    var resistRate: Double {
        let window = eventsInLastDays(Self.weekWindow)
        let resisted = window.filter { $0.kind == .resisted }.count
        let opened = window.filter { $0.kind == .opened }.count
        let total = resisted + opened
        guard total > 0 else { return 0 }
        return Double(resisted) / Double(total)
    }

    // MARK: - Streak

    /// Number of consecutive most-recent events that are `.resisted`.
    /// Any `.opened` event breaks the streak. Empty history is 0.
    var currentResistStreak: Int {
        var streak = 0
        for event in events.sorted(by: { $0.date > $1.date }) {
            guard event.kind == .resisted else { break }
            streak += 1
        }
        return streak
    }

    // MARK: - Per-day breakdown (chart data)

    /// Resisted / opened counts per day for the last `count` days, oldest first.
    /// Days without events are included with zeros (mirrors `SessionStore.dailyMinutes`).
    func dailyFocus(lastDays count: Int) -> [DailyFocus] {
        let today = calendar.startOfDay(for: reference)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let onDay = events.filter { calendar.startOfDay(for: $0.date) == day }
            return DailyFocus(
                day: day,
                resisted: onDay.filter { $0.kind == .resisted }.count,
                opened: onDay.filter { $0.kind == .opened }.count
            )
        }
    }

    struct DailyFocus: Identifiable, Equatable, Sendable {
        let day: Date
        let resisted: Int
        let opened: Int
        var id: Date { day }
    }

    // MARK: - Helpers

    /// Events whose day falls within the last `count` day-buckets ending on the
    /// reference day (inclusive), using the injected calendar's time zone.
    private func eventsInLastDays(_ count: Int) -> [FocusEvent] {
        let today = calendar.startOfDay(for: reference)
        guard let start = calendar.date(byAdding: .day, value: -(count - 1), to: today) else {
            return []
        }
        return events.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= start && day <= today
        }
    }
}
