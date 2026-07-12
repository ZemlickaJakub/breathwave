import DeviceActivity
import FamilyControls
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

        // Lift the shield so the apps open, and record the choice.
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        FocusEventLog.append(FocusEvent(date: Date(), kind: .opened, grantedMinutes: minutes))

        scheduleGraceEnd(minutes: minutes)
    }

    /// Re-shield after the grace window. The window is primarily *usage* based —
    /// a DeviceActivity event fires once the guarded apps have been used for the
    /// chosen number of minutes — with a 15-minute wall-clock interval as a
    /// backstop (the shortest a plain interval can reliably run) in case the
    /// usage event misbehaves. The monitor extension re-applies the shield.
    private func scheduleGraceEnd(minutes: Int) {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let now = Date()
        let backstopEnd = calendar.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(15 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: backstopEnd),
            repeats: false
        )

        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        if let selection = loadSelection() {
            events[DeviceActivityEvent.Name(FocusShared.graceEventName)] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: max(1, minutes))
            )
        }

        let name = DeviceActivityName(FocusShared.graceActivityName)
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule, events: events)
    }

    private func loadSelection() -> FamilyActivitySelection? {
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return nil
        }
        return selection
    }
}
