import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import UserNotifications

/// Re-locks breathed-past apps. The authoritative re-lock signal is a usage
/// threshold on the app-armed daily schedule (`eventDidReachThreshold`) — that
/// path renders our custom shield mid-use. The wall-clock backstop schedule
/// (armed by the shield-action extension) only mops up unlocks whose usage
/// never reached the threshold because the user left the app early; it fires
/// with the user elsewhere, so its generic rendering is never seen.
final class FocusMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()
    /// Re-locks go through this secondary store, NOT the main one the token
    /// was lifted from — lifting only the tapped token from a store the shield
    /// was drawn from is part of keeping iOS on the custom-shield path.
    private let relockStore = ManagedSettingsStore(named: .init(FocusShared.relockStoreName))

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == DeviceActivityName(FocusShared.dayActivityName) else { return }
        if event.rawValue.hasPrefix(FocusShared.warnEventPrefix) {
            FocusShared.debugLog("monitor", "usage warning threshold (\(event.rawValue))")
            postRelockWarning()
            return
        }
        guard event.rawValue.hasPrefix(FocusShared.openEventPrefix) else { return }
        FocusShared.debugLog("monitor", "usage threshold (\(event.rawValue)) → relock")
        // The threshold is the authoritative re-lock: it only fires after real
        // guarded-app use, so the wall-clock grace guard must not veto it (a
        // leftover budget slice can run out before the wall-clock window does).
        FocusShared.defaults.set(0, forKey: FocusShared.Keys.relockAt)
        // The backstop is now redundant for this unlock; letting it fire later
        // would pointlessly re-stamp lastRelockAt and swallow a shield tap.
        DeviceActivityCenter().stopMonitoring([DeviceActivityName(FocusShared.graceActivityName)])
        reapplyShield(respectGraceWindow: false)
    }

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let known = [FocusShared.graceActivityName, FocusShared.testActivityName]
            .map { DeviceActivityName($0) }
        guard known.contains(activity) else { return }
        FocusShared.debugLog("monitor", "intervalDidStart (\(activity.rawValue))")
        // The diagnostics test lock must fire even with guarding off and
        // ignores the grace guard — it exists to test rendering, not policy.
        let isTest = activity == DeviceActivityName(FocusShared.testActivityName)
        reapplyShield(requireGuarding: !isTest, respectGraceWindow: !isTest)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == DeviceActivityName(FocusShared.graceActivityName) else { return }
        FocusShared.debugLog("monitor", "intervalDidEnd")
        reapplyShield()
    }

    private func reapplyShield(requireGuarding: Bool = true, respectGraceWindow: Bool = true) {
        if requireGuarding {
            guard FocusShared.defaults.bool(forKey: FocusShared.Keys.guarding) else { return }
        }
        if respectGraceWindow {
            // If the user is still inside a live grace window — they just chose
            // to open past the shield — a stray monitor callback (e.g. the
            // previous interval ending as we reschedule) must NOT slam the
            // shield back on; that cancels the fresh unlock and forces a
            // pointless second pass. Only re-lock once we've actually reached
            // the scheduled re-lock moment (small tolerance for jitter).
            let relockAt = FocusShared.defaults.double(forKey: FocusShared.Keys.relockAt)
            if relockAt > 0, Date().timeIntervalSince1970 < relockAt - 30 {
                FocusShared.debugLog("monitor", "reapply skipped — mid grace window")
                return
            }
        }
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            FocusShared.debugLog("monitor", "reapply aborted — no selection")
            return
        }
        // Re-lock via the SECONDARY store — the token was lifted from the main
        // one, and re-shielding through a different store makes iOS recycle the
        // last rendered custom shield instead of the generic system screen.
        // Union into the existing set and NEVER write nil to any property:
        // both wholesale replacement and nil writes are suspected of evicting
        // the cached custom shield.
        var apps = relockStore.shield.applications ?? []
        apps.formUnion(selection.applicationTokens)
        if !apps.isEmpty { relockStore.shield.applications = apps }
        let categories = selection.categoryTokens
        if !categories.isEmpty { relockStore.shield.applicationCategories = .specific(categories) }
        // Re-arm the website shield too, matching how the app applies it.
        var webDomains = relockStore.shield.webDomains ?? []
        webDomains.formUnion(selection.webDomainTokens)
        if !webDomains.isEmpty { relockStore.shield.webDomains = webDomains }
        if !categories.isEmpty { relockStore.shield.webDomainCategories = .specific(categories) }
        // Stamp the re-lock so the action extension can tell the generic
        // shield's OK (arrives within seconds) from a genuine later tap.
        FocusShared.defaults.set(Date().timeIntervalSince1970, forKey: FocusShared.Keys.lastRelockAt)
        FocusShared.debugLog("monitor", "reapplied shield (relock store) — apps:\(apps.count) web:\(webDomains.count)")
        // Keep this process alive briefly so the settings write finishes
        // propagating (XPC) before the system reaps the extension — production
        // blockers do the same; dying too early is suspected of leaving the
        // shield to render without our configuration.
        Thread.sleep(forTimeInterval: 2.5)
    }

    /// Post the "locks in 2 minutes" banner right away — the warn threshold
    /// already encodes the lead time in usage minutes. Copy is localized by the
    /// app and shared via the App Group (no String Catalog in this extension).
    private func postRelockWarning() {
        let content = UNMutableNotificationContent()
        content.title = FocusShared.defaults.string(forKey: FocusShared.Keys.relockWarningTitle)
            ?? "Take a breath"
        content.body = FocusShared.defaults.string(forKey: FocusShared.Keys.relockWarningBody)
            ?? "This app locks in 2 minutes."
        let request = UNNotificationRequest(
            identifier: FocusShared.relockWarningNotificationID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
