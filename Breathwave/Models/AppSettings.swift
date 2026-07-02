import Foundation
import Observation

/// User preferences, backed by UserDefaults.
@MainActor
@Observable
final class AppSettings {
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }
    /// Breathing sessions run with a near-black screen, guided by haptics and sound.
    var inTheDarkEnabled: Bool {
        didSet { defaults.set(inTheDarkEnabled, forKey: Keys.inTheDark) }
    }
    var healthSyncEnabled: Bool {
        didSet { defaults.set(healthSyncEnabled, forKey: Keys.healthSync) }
    }
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) }
    }
    var breathSound: BreathSound {
        didSet { defaults.set(breathSound.rawValue, forKey: Keys.breathSound) }
    }
    var gongSound: GongSound {
        didSet { defaults.set(gongSound.rawValue, forKey: Keys.gongSound) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        inTheDarkEnabled = defaults.bool(forKey: Keys.inTheDark)
        healthSyncEnabled = defaults.bool(forKey: Keys.healthSync)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        breathSound = BreathSound(rawValue: defaults.string(forKey: Keys.breathSound) ?? "") ?? .ocean
        // A previously stored "zenBowl" no longer parses and falls back here.
        gongSound = GongSound(rawValue: defaults.string(forKey: Keys.gongSound) ?? "") ?? .chime
    }

    private enum Keys {
        static let haptics = "settings.haptics"
        static let inTheDark = "settings.inTheDark"
        static let healthSync = "settings.healthSync"
        static let onboarding = "onboarding.completed"
        static let breathSound = "settings.breathSound"
        static let gongSound = "settings.gongSound"
    }
}
