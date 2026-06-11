import Foundation
import Observation

/// User preferences, backed by UserDefaults.
@MainActor
@Observable
final class AppSettings {
    var soundEnabled: Bool {
        didSet { defaults.set(soundEnabled, forKey: Keys.sound) }
    }
    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
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
        soundEnabled = defaults.object(forKey: Keys.sound) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        healthSyncEnabled = defaults.bool(forKey: Keys.healthSync)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        breathSound = BreathSound(rawValue: defaults.string(forKey: Keys.breathSound) ?? "") ?? .ocean
        gongSound = GongSound(rawValue: defaults.string(forKey: Keys.gongSound) ?? "") ?? .bowl
    }

    private enum Keys {
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let healthSync = "settings.healthSync"
        static let onboarding = "onboarding.completed"
        static let breathSound = "settings.breathSound"
        static let gongSound = "settings.gongSound"
    }
}
