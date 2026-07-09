import DeviceActivity
import Foundation
import ManagedSettings

/// Handles taps on the mindful-pause shield. One button closes the app; the
/// other opens every guarded app for a short grace window and schedules the
/// shield to return. Which physical button is which was randomised by the
/// configuration extension and recorded in the shared App Group.
final class ShieldActionProvider: ShieldActionDelegate {
    private let store = ManagedSettingsStore()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let pressedPrimary: Bool
        switch action {
        case .primaryButtonPressed: pressedPrimary = true
        case .secondaryButtonPressed: pressedPrimary = false
        @unknown default: pressedPrimary = false
        }
        let openIsPrimary = FocusShared.defaults.bool(forKey: FocusShared.Keys.openIsPrimary)

        if pressedPrimary == openIsPrimary {
            openForGraceWindow()
        } else {
            FocusEventLog.append(FocusEvent(date: Date(), kind: .resisted))
        }
        completionHandler(.close)
    }

    private func openForGraceWindow() {
        let minutes = FocusShared.defaults.object(forKey: FocusShared.Keys.graceMinutes) as? Int
            ?? FocusShared.defaultGraceMinutes

        // Lift the shield so the apps open, and record the choice.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        FocusEventLog.append(FocusEvent(date: Date(), kind: .opened, grantedMinutes: minutes))

        scheduleGraceEnd(minutes: minutes)
    }

    /// Ask DeviceActivity to notify the monitor extension when the window ends,
    /// so the shield returns even though this extension is no longer running.
    private func scheduleGraceEnd(minutes: Int) {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let now = Date()
        let end = calendar.date(byAdding: .minute, value: max(1, minutes), to: now)
            ?? now.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        let name = DeviceActivityName(FocusShared.graceActivityName)
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule)
    }
}
