import DeviceActivity
import Foundation
import ManagedSettings

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

        // Lift the shield so the apps (and their sites) open, and record the choice.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        FocusEventLog.append(FocusEvent(date: Date(), kind: .opened, grantedMinutes: minutes))

        scheduleGraceEnd(minutes: minutes)
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
