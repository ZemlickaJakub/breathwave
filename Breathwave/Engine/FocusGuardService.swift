import Foundation
import Observation
import FamilyControls
import ManagedSettings

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
        didSet { defaults.set(graceMinutes, forKey: FocusShared.Keys.graceMinutes) }
    }

    @ObservationIgnored private let store = ManagedSettingsStore()
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
    }

    func stopGuarding() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        isGuarding = false
        defaults.set(false, forKey: Keys.guarding)
    }

    private func applyShield() {
        let apps = selection.applicationTokens
        store.shield.applications = apps.isEmpty ? nil : apps
        let categories = selection.categoryTokens
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    }

    private func persistSelection() {
        if let data = try? JSONEncoder().encode(selection) {
            defaults.set(data, forKey: Keys.selection)
        }
        // Keep a live shield in sync when the user edits the app list.
        if isGuarding { applyShield() }
    }

    private enum Keys {
        static let selection = "focus.selection"
        static let guarding = "focus.guarding"
    }
}
