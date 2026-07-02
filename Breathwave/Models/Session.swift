import Foundation

/// A completed breathing, meditation, or breath-sensing session.
struct Session: Identifiable, Hashable, Codable, Sendable {
    enum Kind: Hashable, Codable, Sendable {
        case breathing(protocolID: String)
        case meditation
        /// Motion-sensed breathing: the phone on the belly measured the breath.
        case breathSensing
    }

    let id: UUID
    /// Moment the session ended.
    let completedAt: Date
    /// Actual practiced time in seconds.
    let duration: TimeInterval
    let kind: Kind
    /// Breath-sensing sessions record how even the rhythm was (0...1).
    let steadiness: Double?

    init(
        id: UUID = UUID(),
        completedAt: Date,
        duration: TimeInterval,
        kind: Kind,
        steadiness: Double? = nil
    ) {
        self.id = id
        self.completedAt = completedAt
        self.duration = duration
        self.kind = kind
        self.steadiness = steadiness
    }
}
