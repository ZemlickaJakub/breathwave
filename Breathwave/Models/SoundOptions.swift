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

/// Gong character: the singing bowl, or a short gentle chime.
enum GongSound: String, CaseIterable, Identifiable, Sendable {
    case bowl
    case chime

    var id: String { rawValue }

    var nameKey: String {
        switch self {
        case .bowl: "Singing bowl"
        case .chime: "Chime"
        }
    }
}
