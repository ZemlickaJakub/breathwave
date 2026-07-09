import Foundation

/// A bloom-themed milestone that rewards resisting the Mindful Pause shield.
///
/// `title` and `detail` are English strings used directly as String Catalog keys.
struct FocusBadge: Identifiable, Hashable, Sendable {
    let id: String
    /// English key (localized in the String Catalog).
    let title: String
    let systemImage: String
    /// English key (localized in the String Catalog).
    let detail: String
}

/// Pure evaluation of which badges a set of `FocusEvent`s has earned.
///
/// Storage-agnostic: works only on the injected events array; deterministic and
/// testable via the injected `asOf` date and `calendar`.
enum FocusBadges {
    /// Minimum weekly shield encounters before the resist-rate badge can be earned,
    /// so "80% this week" reflects a real habit rather than a single lucky pause.
    static let rateBadgeMinSample = 5
    /// Consecutive resisted encounters required for the streak badge.
    static let streakBadgeThreshold = 7
    /// Resist rate required for the weekly rate badge.
    static let rateBadgeThreshold = 0.80

    // MARK: - Catalog

    /// All badges in display order (locked ones included).
    static let catalog: [FocusBadge] = [
        FocusBadge(
            id: "first_resist",
            title: "First Bloom",
            systemImage: "camera.macro",
            detail: "You let the urge pass for the first time."
        ),
        FocusBadge(
            id: "resist_10",
            title: "Ten Petals",
            systemImage: "leaf.fill",
            detail: "Ten pauses resisted. The habit is taking root."
        ),
        FocusBadge(
            id: "resist_50",
            title: "Fifty in Flower",
            systemImage: "laurel.leading",
            detail: "Fifty small wins over the scroll."
        ),
        FocusBadge(
            id: "resist_100",
            title: "A Hundred Blooms",
            systemImage: "laurel.trailing",
            detail: "One hundred times you chose to stay present."
        ),
        FocusBadge(
            id: "streak_7",
            title: "Unbroken Garden",
            systemImage: "sparkles",
            detail: "Seven shield encounters resisted in a row."
        ),
        FocusBadge(
            id: "clean_day",
            title: "Day in Full Bloom",
            systemImage: "sun.max.fill",
            detail: "A whole day facing the shield without opening once."
        ),
        FocusBadge(
            id: "rate_80",
            title: "Thriving",
            systemImage: "rosette",
            detail: "You resisted at least 80% of the time this week."
        ),
    ]

    private static let byID: [String: FocusBadge] = Dictionary(
        uniqueKeysWithValues: catalog.map { ($0.id, $0) }
    )

    static func badge(id: String) -> FocusBadge? { byID[id] }

    // MARK: - Evaluation

    /// IDs of every badge earned by the given events.
    static func earned(
        from events: [FocusEvent],
        asOf reference: Date = .now,
        calendar: Calendar = .current
    ) -> Set<String> {
        let evaluation = Evaluation(events: events, reference: reference, calendar: calendar)
        return Set(catalog.filter { isEarned($0, evaluation) }.map(\.id))
    }

    /// The full catalog paired with whether each badge is earned — for a UI that
    /// shows both locked and unlocked badges.
    static func status(
        from events: [FocusEvent],
        asOf reference: Date = .now,
        calendar: Calendar = .current
    ) -> [(badge: FocusBadge, isEarned: Bool)] {
        let evaluation = Evaluation(events: events, reference: reference, calendar: calendar)
        return catalog.map { ($0, isEarned($0, evaluation)) }
    }

    private static func isEarned(_ badge: FocusBadge, _ e: Evaluation) -> Bool {
        switch badge.id {
        case "first_resist": return e.totalResisted >= 1
        case "resist_10":    return e.totalResisted >= 10
        case "resist_50":    return e.totalResisted >= 50
        case "resist_100":   return e.totalResisted >= 100
        case "streak_7":     return e.currentResistStreak >= streakBadgeThreshold
        case "clean_day":    return e.hasCleanDay
        case "rate_80":      return e.weekTotal >= rateBadgeMinSample && e.resistRate >= rateBadgeThreshold
        default:             return false
        }
    }

    /// Precomputed values shared across badge checks.
    private struct Evaluation {
        let totalResisted: Int
        let currentResistStreak: Int
        let resistRate: Double
        let weekTotal: Int
        let hasCleanDay: Bool

        init(events: [FocusEvent], reference: Date, calendar: Calendar) {
            let stats = FocusStats(events: events, asOf: reference, calendar: calendar)
            totalResisted = stats.totalResisted
            currentResistStreak = stats.currentResistStreak
            resistRate = stats.resistRate

            let week = stats.dailyFocus(lastDays: FocusStats.weekWindow)
            weekTotal = week.reduce(0) { $0 + $1.resisted + $1.opened }

            // A "clean day": some day had at least one resist and zero opens.
            var resistedByDay: [Date: Int] = [:]
            var openedByDay: [Date: Int] = [:]
            for event in events {
                let day = calendar.startOfDay(for: event.date)
                switch event.kind {
                case .resisted: resistedByDay[day, default: 0] += 1
                case .opened:   openedByDay[day, default: 0] += 1
                }
            }
            hasCleanDay = resistedByDay.contains { day, count in
                count >= 1 && (openedByDay[day] ?? 0) == 0
            }
        }
    }
}
