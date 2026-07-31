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
        reapplyShield()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        guard activity == DeviceActivityName(FocusShared.graceActivityName) else { return }
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
        if relockAt > 0, Date().timeIntervalSince1970 < relockAt - 30 { return }
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        let apps = selection.applicationTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        // Re-arm the website shield too, matching how the app applies it.
        let webDomains = selection.webDomainTokens
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
    }
}
