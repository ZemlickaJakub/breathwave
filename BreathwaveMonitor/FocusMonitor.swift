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
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return
        }
        let apps = selection.applicationTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }
}
