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
        /// Which physical shield button is "open" this presentation, so the
        /// action extension knows what the user actually tapped.
        static let openIsPrimary = "focus.openIsPrimary"
        static let events = "focus.events"
    }

    static let defaultGraceMinutes = 5
    static let graceChoices = [1, 3, 5, 10, 15, 30]

    /// DeviceActivity schedule that re-applies the shield when a grace window ends.
    static let graceActivityName = "focus.grace"
}
