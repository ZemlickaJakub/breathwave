import Foundation

/// Breathing-guide sound character. Ocean is the default surf, breeze is
/// a lighter airy wash, breath mimics calm human breathing, off is silent.
enum BreathSound: String, CaseIterable, Identifiable, Sendable {
    case ocean
    case breeze
    case breath
    case off

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .ocean: "Ocean"
        case .breeze: "Breeze"
        case .breath: "Breath"
        case .off: "Off"
        }
    }

    /// Timbre for the breath-synced session sound; nil renders silence.
    var timbre: OceanProgram.Timbre? {
        switch self {
        case .ocean: .surf
        case .breeze: .breeze
        case .breath: .breath
        case .off: nil
        }
    }

    /// Timbre for the steady meditation ambient. A constant breath noise
    /// would just hiss, so breath falls back to surf.
    var ambientTimbre: OceanProgram.Timbre? {
        switch self {
        case .ocean, .breath: .surf
        case .breeze: .breeze
        case .off: nil
        }
    }
}

/// Gong character. The sounds play bundled samples (Resources/Sounds)
/// with a synthesized fallback; off skips gongs entirely.
enum GongSound: String, CaseIterable, Identifiable, Sendable {
    case chime
    case zenBowl
    case off

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .chime: "Chime"
        case .zenBowl: "Zen bowl"
        case .off: "Off"
        }
    }

    private var sampleResourceName: String? {
        switch self {
        case .chime: "gong-chime"
        case .zenBowl: "gong-zen-bowl"
        case .off: nil
        }
    }

    nonisolated var sampleURL: URL? {
        guard let sampleResourceName else { return nil }
        for ext in ["caf", "wav", "m4a", "aiff", "mp3"] {
            if let url = Bundle.main.url(forResource: sampleResourceName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
