import DeviceActivity
import Foundation
import ManagedSettings
import UserNotifications

/// Handles taps on the mindful-pause shield. One button closes the app; the
/// other opens the tapped item for a short grace window and schedules the
/// shield to return. Which physical button opens is derived from the app token,
/// identically to the configuration extension that drew the shield.
final class ShieldActionProvider: ShieldActionDelegate {
    private let store = ManagedSettingsStore()
    /// The monitor re-locks via this secondary store, so lifting must clear
    /// the token from both — a token shielded in ANY store stays blocked.
    private let relockStore = ManagedSettingsStore(named: .init(FocusShared.relockStoreName))

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(application), lift: {
            // Remove ONLY this app, keeping the rest of the shield set alive.
            // Never nil the whole shield — that evicts iOS's cached custom
            // configuration for the token, so the re-lock (mid-foreground)
            // falls back to the generic "Restricted" system screen instead of
            // our breathe screen.
            for store in [self.store, self.relockStore] {
                var apps = store.shield.applications ?? []
                apps.remove(application)
                store.shield.applications = apps
            }
        }, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(webDomain), lift: {
            for store in [self.store, self.relockStore] {
                var domains = store.shield.webDomains ?? []
                domains.remove(webDomain)
                store.shield.webDomains = domains
            }
        }, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, tokenData: ShieldButtons.tokenData(category), lift: {
            for store in [self.store, self.relockStore] {
                if case .specific(var categories, except: let except)? = store.shield.applicationCategories {
                    categories.remove(category)
                    store.shield.applicationCategories = .specific(categories, except: except)
                } else if store.shield.applicationCategories != nil {
                    // `.all()` / unknown policy: can't drop a single token, so clear it.
                    store.shield.applicationCategories = nil
                }
            }
        }, completionHandler: completionHandler)
    }

    private func respond(
        to action: ShieldAction,
        tokenData: Data?,
        lift: @escaping () -> Void,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        // Right after a re-lock the only shield on screen is the system's
        // generic one (single OK button). Its OK must never fall into the
        // "open" branch — that would re-unlock the app and loop forever
        // (confirmed on device: reapply at T, tap → open at T+1s, repeatedly).
        // A genuine re-open of our two-button shield takes longer than this.
        let lastRelockAt = FocusShared.defaults.double(forKey: FocusShared.Keys.lastRelockAt)
        if lastRelockAt > 0,
           Date().timeIntervalSince1970 - lastRelockAt < FocusShared.relockTapWindowSeconds {
            // Not a mindful choice — no FocusEvent recorded.
            FocusShared.debugLog("shieldAction", "tap within relock window → forced close")
            completionHandler(.close)
            return
        }

        let pressedPrimary: Bool
        switch action {
        case .primaryButtonPressed: pressedPrimary = true
        case .secondaryButtonPressed: pressedPrimary = false
        @unknown default: pressedPrimary = false
        }
        let openIsPrimary = ShieldButtons.openIsPrimary(tokenData: tokenData)

        FocusShared.debugLog("shieldAction", "tap primary:\(pressedPrimary) openIsPrimary:\(openIsPrimary) → \(pressedPrimary == openIsPrimary ? "open" : "notNow")")
        if pressedPrimary == openIsPrimary {
            openForGraceWindow(lift: lift, completionHandler: completionHandler)
        } else {
            FocusEventLog.append(FocusEvent(date: Date(), kind: .resisted))
            // "Not now" — send them back Home, don't reveal the app.
            completionHandler(.close)
        }
    }

    private func openForGraceWindow(
        lift: @escaping () -> Void,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        let minutes = FocusShared.defaults.object(forKey: FocusShared.Keys.graceMinutes) as? Int
            ?? FocusShared.defaultGraceMinutes
        let delay = FocusShared.openDelaySeconds

        // Mark when the shield should return *before* touching the schedule:
        // rescheduling can fire a stray monitor callback, and the monitor reads
        // this to know we're mid-grace and must not re-lock yet.
        FocusShared.defaults.set(
            Date().timeIntervalSince1970 + delay + Double(minutes * 60),
            forKey: FocusShared.Keys.relockAt
        )
        FocusEventLog.append(FocusEvent(date: Date(), kind: .opened, grantedMinutes: minutes))

        scheduleRelockWarning(minutes: minutes)
        scheduleGraceEnd(minutes: minutes)

        // Hold the shield up for a few breaths, THEN lift and defer — the
        // response stays pending the whole wait, the way ScreenZen's
        // "Open (in 5s)" behaves. The pause is the point; it also keeps the
        // shield pipeline alive while the unshield lands. Blocking this
        // handler's thread is fine: the extension exists only to answer taps.
        // NOT .close: that bounces to the Home screen. Deferring after the lift
        // lets iOS reveal the app already sitting underneath the shield.
        // completionHandler must be the last thing we call.
        Thread.sleep(forTimeInterval: delay)
        lift()
        FocusShared.debugLog("shieldAction", "deferred open after \(Int(delay))s")
        completionHandler(.defer)
    }

    /// Post a gentle heads-up a couple of minutes before the apps re-lock, so the
    /// re-lock isn't a hard surprise. Copy is localized by the app and shared via
    /// the App Group (this extension has no String Catalog of its own). Skipped
    /// when the grace window is too short for a lead time to make sense.
    private func scheduleRelockWarning(minutes: Int) {
        // The grace window starts after the in-shield pause, so shift by it.
        let lead = FocusShared.openDelaySeconds
            + TimeInterval((minutes - FocusShared.relockWarningLeadMinutes) * 60)
        guard lead > FocusShared.openDelaySeconds else { return }

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
        // The grace window starts after the in-shield pause.
        let now = Date().addingTimeInterval(FocusShared.openDelaySeconds)
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
