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

/// Gong character. Both options play bundled samples (Resources/Sounds);
/// a synthesized fallback covers a missing file.
enum GongSound: String, CaseIterable, Identifiable, Sendable {
    case chime
    case zenBowl

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .chime: "Chime"
        case .zenBowl: "Zen bowl"
        }
    }

    private var sampleResourceName: String {
        switch self {
        case .chime: "gong-chime"
        case .zenBowl: "gong-zen-bowl"
        }
    }

    nonisolated var sampleURL: URL? {
        for ext in ["caf", "wav", "m4a", "aiff", "mp3"] {
            if let url = Bundle.main.url(forResource: sampleResourceName, withExtension: ext) {
                return url
            }
        }
        return nil
    }
}
