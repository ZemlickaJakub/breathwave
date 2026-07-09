import Foundation

/// Reads and appends Mindful Pause events in the shared App Group so the
/// shield-action extension can record them and the app can show stats.
enum FocusEventLog {
    /// Keep the stored blob bounded; stats never need more than recent history.
    private static let maxEvents = 2000

    static func all() -> [FocusEvent] {
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.events),
              let events = try? JSONDecoder().decode([FocusEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func append(_ event: FocusEvent) {
        var events = all()
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        if let data = try? JSONEncoder().encode(events) {
            FocusShared.defaults.set(data, forKey: FocusShared.Keys.events)
        }
    }
}
