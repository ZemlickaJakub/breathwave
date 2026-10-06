import SwiftUI

/// Near-black pacer for in-the-dark sessions: a dim glow that swells with the
/// breath. Haptics and sound carry the guidance; this is just a quiet anchor
/// for half-open eyes (and the only cue on devices without haptics).
struct DarkPacerView: View {
    let snapshot: BreathingEngine.Snapshot?

    private static let minRadius = 26.0
    private static let maxRadius = 110.0

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(.white.opacity(0.4))
                .frame(width: 5, height: 5)
        }
        .frame(width: Self.maxRadius * 2, height: Self.maxRadius * 2)
    }

    private var radius: Double {
        Self.minRadius + (Self.maxRadius - Self.minRadius) * (snapshot?.lungFill ?? 0)
    }
}
