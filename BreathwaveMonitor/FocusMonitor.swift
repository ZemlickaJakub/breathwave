import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

/// Puts the shield back on the guarded apps once a grace window ends — either
/// when the guarded apps have been used for the chosen number of minutes (the
/// usage event) or when the wall-clock backstop interval ends — as long as
/// guarding is still switched on.
final class FocusMonitor: DeviceActivityMonitor {
    private let store = ManagedSettingsStore()

    override func eventDidReachThreshold(
        _ event: DeviceActivityEvent.Name,
        activity: DeviceActivityName
    ) {
        super.eventDidReachThreshold(event, activity: activity)
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
