import DeviceActivity
import Foundation
import Observation
import FamilyControls
import ManagedSettings
import UserNotifications

/// Guards user-chosen apps behind a mindful pause. Wraps Screen Time
/// authorization, the app picker's selection, and the shield that is applied
/// to the chosen apps. Selection tokens are opaque — the app never learns
/// which apps were picked, and nothing leaves the device.
@MainActor
@Observable
final class FocusGuardService {
    enum Authorization {
        case undetermined, approved, denied
    }

    private(set) var authorization: Authorization = .undetermined
    /// Apps and categories the user chose to guard. Persisted as opaque tokens.
    var selection: FamilyActivitySelection {
        didSet { persistSelection() }
    }
    /// Whether the shield is currently applied.
    private(set) var isGuarding: Bool
    /// How long a guarded app stays open after the user chooses to breathe past it.
    var graceMinutes: Int {
        didSet {
            defaults.set(graceMinutes, forKey: FocusShared.Keys.graceMinutes)
            // The usage thresholds are multiples of the grace minutes; a new
            // value needs a fresh set of events.
            if isGuarding { armUsageBudget() }
        }
    }

    @ObservationIgnored private let store = ManagedSettingsStore()
    /// Secondary store the monitor re-locks through; must be cleared whenever
    /// guarding stops so nothing stays shielded behind the user's back.
    @ObservationIgnored private let relockStore = ManagedSettingsStore(named: .init(FocusShared.relockStoreName))
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = FocusShared.defaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: FocusShared.Keys.selection),
           let decoded = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) {
            selection = decoded
        } else {
            selection = FamilyActivitySelection()
        }
        isGuarding = defaults.bool(forKey: FocusShared.Keys.guarding)
        graceMinutes = defaults.object(forKey: FocusShared.Keys.graceMinutes) as? Int
            ?? FocusShared.defaultGraceMinutes
        refreshAuthorization()
        // Keep the shared warning copy fresh (e.g. after a language change) so
        // the action extension always posts it in the current locale.
        storeRelockWarningCopy()
        // Re-arm the shield after a relaunch so guarding survives restarts.
        if isGuarding { applyShield() }
    }

    /// True once the user has picked at least one app or category.
    var hasSelection: Bool {
        !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty
    }

    func requestAuthorization() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            // A refused or failed prompt leaves us unauthorized; reflect that.
        }
        refreshAuthorization()
    }

    func refreshAuthorization() {
        switch AuthorizationCenter.shared.authorizationStatus {
        case .approved: authorization = .approved
        case .denied: authorization = .denied
        default: authorization = .undetermined
        }
    }

    func startGuarding() {
        guard authorization == .approved, hasSelection else { return }
        applyShield()
        isGuarding = true
        defaults.set(true, forKey: Keys.guarding)
        armUsageBudget()
        // The re-lock warning needs notification permission; ask the first time
        // the pause is switched on so it's granted before any shield appears.
        requestNotificationAuthorization()
    }

    func stopGuarding() {
        clearShield()
        isGuarding = false
        defaults.set(false, forKey: Keys.guarding)
        DeviceActivityCenter().stopMonitoring([
            DeviceActivityName(FocusShared.dayActivityName),
            DeviceActivityName(FocusShared.graceActivityName),
        ])
    }

    private func applyShield() {
        // Mid grace window (user just breathed past the shield), re-shielding
        // now would cut the unlock short — e.g. merely opening Breathwave from
        // the re-lock warning notification would slam the app shut early. Let
        // the monitor's scheduled re-lock handle it instead.
        let relockAt = defaults.double(forKey: FocusShared.Keys.relockAt)
        if relockAt > 0, Date().timeIntervalSince1970 < relockAt - 30 {
            FocusShared.debugLog("app", "applyShield skipped — mid grace window")
            return
        }
        let apps = selection.applicationTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        // Also shield the matching websites in Safari. Without this, opening a
        // guarded app's site (e.g. instagram.com) falls back to the system's
        // plain "restricted" page instead of our breathe screen.
        let webDomains = selection.webDomainTokens
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        FocusShared.debugLog("app", "applyShield — apps:\(apps.count) web:\(webDomains.count)")
    }

    private func clearShield() {
        for store in [store, relockStore] {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            store.shield.webDomainCategories = nil
        }
        // No live grace window any more; drop the marker and any pending warning.
        defaults.set(0, forKey: FocusShared.Keys.relockAt)
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [FocusShared.relockWarningNotificationID])
    }

    /// Arms the daily schedule carrying the usage-threshold events that
    /// re-lock a breathed-past app. This MUST run in the main app: monitoring
    /// registered here renders our custom shield on a mid-use re-lock, while
    /// the same registration from an extension yields the system's generic
    /// "Restricted" screen (proven on device, 2026-08-05). The thresholds are
    /// cumulative — lock after 1×grace, 2×grace, … minutes of guarded-app
    /// use — so every unlock of the day is covered in advance, no scheduling
    /// needed at "Open" time. Re-arming resets the day's accumulation.
    private func armUsageBudget() {
        let center = DeviceActivityCenter()
        let day = DeviceActivityName(FocusShared.dayActivityName)
        center.stopMonitoring([day])
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true
        )
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for step in 1...FocusShared.dailyBudgetSlices {
            events[.init(FocusShared.openEventName(step))] = usageEvent(minutes: step * graceMinutes)
            // A heads-up a couple of usage-minutes before each lock; pointless
            // when the whole window is shorter than the lead time.
            if graceMinutes > FocusShared.relockWarningLeadMinutes {
                events[.init(FocusShared.warnEventName(step))] = usageEvent(
                    minutes: step * graceMinutes - FocusShared.relockWarningLeadMinutes
                )
            }
        }
        do {
            try center.startMonitoring(day, during: schedule, events: events)
            FocusShared.debugLog("app", "armed usage budget — \(events.count) events, grace \(graceMinutes) min")
        } catch {
            FocusShared.debugLog("app", "usage budget arming failed: \(error)")
        }
    }

    private func usageEvent(minutes: Int) -> DeviceActivityEvent {
        if #available(iOS 17.4, *) {
            // Only count use accrued after arming; otherwise a day of guarded
            // -app use before switching the pause on fires events instantly.
            return DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes),
                includesPastActivity: false
            )
        }
        return DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: minutes)
        )
    }

    private func requestNotificationAuthorization() {
        Task {
            // Alerts only — the warning is a brief banner, no sound or badge.
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
        }
    }

    /// Publish the warning copy to the App Group so the action extension — which
    /// has no String Catalog — can post a localized notification.
    private func storeRelockWarningCopy() {
        defaults.set(
            String(localized: "Take a breath"),
            forKey: FocusShared.Keys.relockWarningTitle
        )
        defaults.set(
            String(localized: "This app locks in 2 minutes."),
            forKey: FocusShared.Keys.relockWarningBody
        )
    }

    private func persistSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: Keys.selection)
        }
        // Keep a live shield and the usage thresholds in sync when the user
        // edits the app list.
        if isGuarding {
            applyShield()
            armUsageBudget()
        }
    }

    private enum Keys {
        static let selection = "focus.selection"
        static let guarding = "focus.guarding"
    }
}
