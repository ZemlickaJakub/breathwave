import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Puts the shield back on the guarded apps when the grace window ends. The
/// window's re-lock moment is the *start* of the scheduled interval, so the
/// shield returns on `intervalDidStart`; `intervalDidEnd` re-applies too as a
/// harmless safety net. Only acts while guarding is still switched on.
final class FocusMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        guard activity == DeviceActivityName(FocusShared.graceActivityName) else { return }
        FocusShared.debugLog("monitor", "intervalDidStart")
        reapplyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == DeviceActivityName(FocusShared.graceActivityName) else { return }
        FocusShared.debugLog("monitor", "intervalDidEnd")
        reapplyShield()
    }

    private func reapplyShield() {
        guard FocusShared.defaults.bool(forKey: FocusShared.Keys.guarding) else { return }
        // If the user is still inside a live grace window — they just chose to
        // open past the shield — a stray monitor callback (e.g. the previous
        // interval ending as we reschedule) must NOT slam the shield back on;
        // that cancels the fresh unlock and forces a pointless second pass.
        // Only re-lock once we've actually reached the scheduled re-lock moment
        // (small tolerance for scheduling jitter).
        let relockAt = FocusShared.defaults.double(forKey: FocusShared.Keys.relockAt)
        if relockAt > 0, Date().timeIntervalSince1970 < relockAt - 30 {
            FocusShared.debugLog("monitor", "reapply skipped — mid grace window")
            return
        }
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            FocusShared.debugLog("monitor", "reapply aborted — no selection")
            return
        }
        // Add the tokens back INTO the existing shield set rather than replacing
        // it wholesale, and NEVER write nil to any shield property here: nil
        // writes are suspected of evicting iOS's cached custom shield, which
        // makes a mid-foreground re-lock fall back to the generic system screen.
        // Only touch properties that actually gain content.
        var apps = store.shield.applications ?? []
        apps.formUnion(selection.applicationTokens)
        if !apps.isEmpty { store.shield.applications = apps }
        let categories = selection.categoryTokens
        if !categories.isEmpty { store.shield.applicationCategories = .specific(categories) }
        // Re-arm the website shield too, matching how the app applies it.
        var webDomains = store.shield.webDomains ?? []
        webDomains.formUnion(selection.webDomainTokens)
        if !webDomains.isEmpty { store.shield.webDomains = webDomains }
        if !categories.isEmpty { store.shield.webDomainCategories = .specific(categories) }
        FocusShared.debugLog("monitor", "reapplied shield — apps:\(apps.count) web:\(webDomains.count)")
    }
}
