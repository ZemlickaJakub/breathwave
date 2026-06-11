import Foundation

/// One step of a breathing cycle, in breathing order.
enum BreathPhase: String, Codable, CaseIterable, Sendable {
    case inhale
    case holdAfterInhale
    case exhale
    case holdAfterExhale
}

/// Definition of a breathing protocol: four phase durations in seconds.
/// Phases with a zero duration are skipped (e.g. coherent breathing has no holds).
struct BreathingProtocol: Identifiable, Hashable, Codable, Sendable {
    let id: String
    /// Localization key for the display name (entry in Localizable.xcstrings).
    let nameKey: String
    var inhale: TimeInterval
    var holdAfterInhale: TimeInterval
    var exhale: TimeInterval
    var holdAfterExhale: TimeInterval

    struct PhaseSpec: Hashable, Sendable {
        let phase: BreathPhase
        let duration: TimeInterval
    }

    /// Active (non-zero) phases in breathing order.
    var phases: [PhaseSpec] {
        [
            PhaseSpec(phase: .inhale, duration: inhale),
            PhaseSpec(phase: .holdAfterInhale, duration: holdAfterInhale),
            PhaseSpec(phase: .exhale, duration: exhale),
            PhaseSpec(phase: .holdAfterExhale, duration: holdAfterExhale),
        ].filter { $0.duration > 0 }
    }

    var cycleDuration: TimeInterval {
        inhale + holdAfterInhale + exhale + holdAfterExhale
    }

    var localizedName: String {
        String(localized: String.LocalizationValue(nameKey))
    }
}

extension BreathingProtocol {
    static let coherent = BreathingProtocol(
        id: "coherent",
        nameKey: "Coherent Breathing",
        inhale: 5.5, holdAfterInhale: 0, exhale: 5.5, holdAfterExhale: 0
    )

    static let box = BreathingProtocol(
        id: "box",
        nameKey: "Box Breathing",
        inhale: 4, holdAfterInhale: 4, exhale: 4, holdAfterExhale: 4
    )

    static let fourSevenEight = BreathingProtocol(
        id: "four-seven-eight",
        nameKey: "4-7-8",
        inhale: 4, holdAfterInhale: 7, exhale: 8, holdAfterExhale: 0
    )

    static let extendedExhale = BreathingProtocol(
        id: "extended-exhale",
        nameKey: "Extended Exhale",
        inhale: 4, holdAfterInhale: 0, exhale: 6, holdAfterExhale: 0
    )

    /// Built-in presets shown on the home screen.
    /// The fifth protocol (custom rhythm with saved presets) comes in Phase 2.
    static let presets: [BreathingProtocol] = [.coherent, .box, .fourSevenEight, .extendedExhale]
}
