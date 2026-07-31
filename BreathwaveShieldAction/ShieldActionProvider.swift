import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// Handles taps on the mindful-pause shield. One button closes the app; the
/// other opens every guarded app for a short grace window and schedules the
/// shield to return. Which physical button opens is derived from the app token,
/// identically to the configuration extension that drew the shield.
final class ShieldActionProvider: ShieldActionDelegate {
    private let store = ManagedSettingsStore()

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(application), completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(webDomain), completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(category), completionHandler: completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        tokenData: Data?,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let pressedPrimary: Bool
        switch action {
        case .primaryButtonPressed: pressedPrimary = true
        case .secondaryButtonPressed: pressedPrimary = false
        @unknown default: pressedPrimary = false
        }
        let openIsPrimary = ShieldButtons.openIsPrimary(tokenData: tokenData)

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

        // Mark when the shield should return *before* touching the schedule:
        // rescheduling can fire a stray monitor callback, and the monitor reads
        // this to know we're mid-grace and must not re-lock yet.
        FocusShared.defaults.set(
            Date().timeIntervalSince1970 + Double(minutes * 60),
            forKey: FocusShared.Keys.relockAt
        )

        // Lift the shield so the apps (and their sites) open, and record the choice.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        FocusEventLog.append(FocusEvent(date: Date(), kind: .opened, grantedMinutes: minutes))

        scheduleRelockWarning(minutes: minutes)
        scheduleGraceEnd(minutes: minutes)
    }

    /// Post a gentle heads-up a couple of minutes before the apps re-lock, so the
    /// re-lock isn't a hard surprise. Copy is localized by the app and shared via
    /// the App Group (this extension has no String Catalog of its own). Skipped
    /// when the grace window is too short for a lead time to make sense.
    private func scheduleRelockWarning(minutes: Int) {
        let lead = TimeInterval((minutes - FocusShared.relockWarningLeadMinutes) * 60)
        guard lead > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = FocusShared.defaults.string(forKey: FocusShared.Keys.relockWarningTitle)
            ?? "Take a breath"
        content.body = FocusShared.defaults.string(forKey: FocusShared.Keys.relockWarningBody)
            ?? "This app locks in 2 minutes."

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: lead, repeats: false)
        let request = UNNotificationRequest(
            identifier: FocusShared.relockWarningNotificationID,
            content: content,
            trigger: trigger
        )
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [FocusShared.relockWarningNotificationID])
        center.add(request)
    }

    /// Re-shield exactly `minutes` from now, on the wall clock. DeviceActivity
    /// won't fire an interval shorter than 15 minutes, but that limit is on the
    /// interval's *length* — its start can be any time. So the interval starts
    /// at the re-lock moment (now + minutes) and runs a full 15 minutes past it;
    /// the monitor re-applies the shield on `intervalDidStart`.
    private func scheduleGraceEnd(minutes: Int) {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let now = Date()
        let relock = calendar.date(byAdding: .minute, value: max(1, minutes), to: now)
            ?? now.addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        let end = calendar.date(byAdding: .minute, value: 15, to: relock)
            ?? relock.addingTimeInterval(15 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: relock),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        let name = DeviceActivityName(FocusShared.graceActivityName)
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule)
    }
}
