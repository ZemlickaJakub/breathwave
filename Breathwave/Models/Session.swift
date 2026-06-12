import Foundation

/// A completed breathing or meditation session.
struct Session: Identifiable, Hashable, Codable, Sendable {
    enum Kind: Hashable, Codable, Sendable {
        case breathing(protocolID: String)
        case meditation
    }

    let id: UUID
    /// Moment the session ended.
    let completedAt: Date
    /// Actual practiced time in seconds.
    let duration: TimeInterval
    let kind: Kind

    init(id: UUID = UUID(), completedAt: Date, duration: TimeInterval, kind: Kind) {
        self.id = id
        self.completedAt = completedAt
        self.duration = duration
        self.kind = kind
    }
}
