import Foundation

/// One moment the user faced the Mindful Pause shield.
struct FocusEvent: Codable, Identifiable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case resisted   // chose "Not now"
        case opened     // unlocked the app
    }
    let id: UUID
    let date: Date
    let kind: Kind
    /// Minutes the app was unlocked for (only for .opened).
    let grantedMinutes: Int?

    init(id: UUID = UUID(), date: Date, kind: Kind, grantedMinutes: Int? = nil) {
        self.id = id
        self.date = date
        self.kind = kind
        self.grantedMinutes = grantedMinutes
    }
}
