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

    /// Catalog key for the "what is this good for" description.
    var descriptionKey: String {
        "protocol.\(id).description"
    }

    /// Catalog key for the "when to use it" hint.
    var whenKey: String {
        "protocol.\(id).when"
    }

    /// Phase durations as e.g. "4 · 7 · 8" — language-neutral.
    var rhythmSummary: String {
        phases
            .map { $0.duration.formatted(.number.precision(.fractionLength(0...1))) }
            .joined(separator: " · ")
    }

    /// Om training drives a voiced drone instead of the surf and lets the
    /// user adjust the exhale ("om") length.
    var isOmTraining: Bool {
        id == "om"
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

    /// Internal carrier for the meditation timer — reuses the engine's
    /// absolute-time session logic; the phases themselves are not shown.
    static let meditation = BreathingProtocol(
        id: "meditation",
        nameKey: "Meditation",
        inhale: 1, holdAfterInhale: 0, exhale: 1, holdAfterExhale: 0
    )

    /// Om training: deep breath in, long voiced "om" on the exhale.
    /// The exhale length is user-adjustable in the session screen.
    static let om = BreathingProtocol(
        id: "om",
        nameKey: "Om Chanting",
        inhale: 4, holdAfterInhale: 0, exhale: 12, holdAfterExhale: 0
    )
}
