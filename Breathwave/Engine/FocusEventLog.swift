import Foundation

/// Reads and appends Mindful Pause events in the shared App Group so the
/// shield-action extension can record them and the app can show stats.
///
/// Stored as a JSON file in the App Group container, written atomically. The
/// shield-action extension is terminated the instant it finishes handling a
/// tap, so a `UserDefaults` write (which flushes to disk asynchronously) can be
/// lost before it lands — a file write with `.atomic` flushes synchronously and
/// survives, matching how `SessionStore` persists its sessions.
enum FocusEventLog {
    /// Keep the stored history bounded; stats never need more than this.
    private static let maxEvents = 2000

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: FocusShared.appGroup)?
            .appendingPathComponent("focus-events.json")
    }

    static func all() -> [FocusEvent] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([FocusEvent].self, from: data) else {
            return []
        }
        return events
    }

    static func append(_ event: FocusEvent) {
        guard let url = fileURL else { return }
        var events = all()
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        guard let data = try? JSONEncoder().encode(events) else { return }
        // Readable after the first unlock so both the app and the extension can
        // reach it whenever the device has been unlocked since boot.
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
