import Foundation

/// Shared contract between the app and its Family Controls extensions
/// (shield configuration, shield action, device-activity monitor). All three
/// run in separate processes and talk only through this App Group.
enum FocusShared {
    static let appGroup = "group.cz.jakubzemlicka.breathwave"

    /// Shared defaults for the App Group; falls back to standard defaults if
    /// the group is somehow unavailable so nothing crashes.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    enum Keys {
        static let selection = "focus.selection"
        static let guarding = "focus.guarding"
        static let graceMinutes = "focus.graceMinutes"
        /// Wall-clock instant (timeIntervalSince1970) when the shield should snap
        /// back on. While `now` is still before it, the monitor must not re-lock —
        /// that guards against a stray callback cancelling a fresh unlock.
        static let relockAt = "focus.relockAt"
        /// Localized warning copy, written by the app (which owns the String
        /// Catalog) so the action extension can post it without its own catalog.
        static let relockWarningTitle = "focus.relockWarningTitle"
        static let relockWarningBody = "focus.relockWarningBody"
        /// When the monitor last re-applied the shield. Taps arriving moments
        /// after this are the "OK" on the system's generic Restricted screen,
        /// not a mindful choice on our two-button shield.
        static let lastRelockAt = "focus.lastRelockAt"
    }

    /// Taps this soon after a re-lock are treated as "close": the generic
    /// system shield (single OK button) is the only thing on screen right
    /// after a mid-use re-lock, and its OK must never map to "open" — that
    /// re-unlocks the app and loops. A real re-open of our two-button shield
    /// takes longer than this.
    static let relockTapWindowSeconds: Double = 10

    /// Identifier for the single "apps lock again soon" warning notification.
    static let relockWarningNotificationID = "focus.relock.warning"
    /// How many minutes before the re-lock the warning fires.
    static let relockWarningLeadMinutes = 2

    /// Minutes a guarded app stays open after the user breathes past the shield.
    static let defaultGraceMinutes = 5
    static let graceChoices = [1, 3, 5, 10, 15]

    /// DeviceActivity schedule whose start marks the re-lock moment.
    static let graceActivityName = "focus.grace"

    // MARK: Diagnostics

    /// Append-only trace shared by the app and all three extensions, used to see
    /// which process did what (and when) around shield events. Extensions are
    /// killed right after running, so this must hit disk immediately.
    private static var debugLogURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("focus-debug.log")
    }

    static func debugLog(_ source: String, _ event: String) {
        guard let url = debugLogURL else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let line = "\(formatter.string(from: Date())) [\(source)] \(event)\n"
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
        } else {
            try? Data(line.utf8).write(to: url, options: .atomic)
        }
    }

    static func readDebugLog() -> String {
        guard let url = debugLogURL,
              let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        // Show the tail; the interesting events are always the latest ones.
        return String(text.suffix(20_000))
    }

    static func clearDebugLog() {
        guard let url = debugLogURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

/// Decides which physical shield button ("primary" / "secondary") opens the app.
///
/// The layout must swap so the "open" button can't be tapped on reflex, but the
/// configuration extension (which draws the shield) and the action extension
/// (which handles the tap) are separate processes. Rather than hand a value
/// between them — which races and caches badly — both derive the same answer
/// from the guarded app's token and the current hour. Same inputs, same result,
/// no shared state.
enum ShieldButtons {
    static func openIsPrimary(tokenData: Data?, at date: Date = Date()) -> Bool {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        if let tokenData {
            for byte in tokenData {
                hash = (hash ^ UInt64(byte)) &* 0x1_0000_0000_01b3
            }
        }
        let hourBucket = UInt64(max(0, date.timeIntervalSince1970) / 3600)
        hash ^= hourBucket &* 0x9e37_79b9_7f4a_7c15
        return hash & 1 == 0
    }

    /// Stable byte encoding of an opaque Screen Time token, identical across
    /// processes (unlike `Hashable`, whose seed is randomized per launch).
    static func tokenData<Token: Encodable>(_ token: Token?) -> Data? {
        guard let token else { return nil }
        return try? PropertyListEncoder().encode(token)
    }
}
