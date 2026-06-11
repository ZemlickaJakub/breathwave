import Foundation

/// Breathing-guide sound character. Ocean is the default surf;
/// breeze is a lighter, airier wash without the deep rumble.
enum BreathSound: String, CaseIterable, Identifiable, Sendable {
    case ocean
    case breeze

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .ocean: "Ocean"
        case .breeze: "Breeze"
        }
    }

    var timbre: OceanProgram.Timbre {
        switch self {
        case .ocean: .surf
        case .breeze: .breeze
        }
    }
}

/// Gong character: the synthesized singing bowl, a short gentle chime,
/// or a bundled sample (long-stroked zen bowl).
enum GongSound: String, CaseIterable, Identifiable, Sendable {
    case bowl
    case chime
    case zenBowl

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .bowl: "Singing bowl"
        case .chime: "Chime"
        case .zenBowl: "Zen bowl"
        }
    }

    /// The zen bowl plays a licensed sample dropped into Resources/Sounds
    /// as "gong-zen-bowl.<ext>"; the option only appears when the file exists.
    nonisolated static var zenBowlURL: URL? {
        for ext in ["caf", "wav", "m4a", "aiff", "mp3"] {
            if let url = Bundle.main.url(forResource: "gong-zen-bowl", withExtension: ext) {
                return url
            }
        }
        return nil
    }

    var isAvailable: Bool {
        self == .zenBowl ? Self.zenBowlURL != nil : true
    }

    static var available: [GongSound] {
        allCases.filter(\.isAvailable)
    }
}
