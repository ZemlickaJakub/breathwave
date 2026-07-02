import Foundation

/// Visual recipe for one bloom in the garden — derived deterministically
/// from a completed session, so the same session always grows the same
/// flower and the garden can be rebuilt from the session store alone.
struct BloomParameters: Equatable, Sendable {
    var petalCount: Int
    var layerCount: Int
    /// Position on the color wheel, 0...1.
    var baseHue: Double
    /// Petal width relative to its length.
    var petalAspect: Double
    /// Whole-flower rotation in radians.
    var rotationOffset: Double
    /// Per-petal length variation spread; steadier breath grows tidier flowers.
    var petalWobble: Double
    /// Carries the per-petal variation into rendering.
    var seed: UInt64
}

extension BloomParameters {
    static func from(_ session: Session) -> BloomParameters {
        var random = SplitMix64(seed: fnv1a(session.id.uuidString))
        // Longer practice grows fuller flowers: 6 petals up to 12 at 15+ minutes.
        let petalCount = 6 + min(6, Int(session.duration / 150))
        let layerCount = session.duration >= 300 ? 3 : 2
        // Breathing blooms live in sea tones, meditation in violets,
        // sensed breath in greens.
        let hueBand: ClosedRange<Double> = switch session.kind {
        case .breathing: 0.44...0.60
        case .meditation: 0.68...0.80
        case .breathSensing: 0.26...0.38
        }
        let baseHue = hueBand.lowerBound + random.unit() * (hueBand.upperBound - hueBand.lowerBound)
        let petalAspect = 0.35 + random.unit() * 0.25
        let rotationOffset = random.unit() * 2 * .pi
        // A steady measured breath grows a tidy flower; no measurement
        // keeps the default natural wobble.
        let petalWobble = session.steadiness.map { 0.05 + (1 - $0) * 0.18 } ?? 0.16
        return BloomParameters(
            petalCount: petalCount,
            layerCount: layerCount,
            baseHue: baseHue,
            petalAspect: petalAspect,
            rotationOffset: rotationOffset,
            petalWobble: petalWobble,
            seed: random.state
        )
    }

    private static func fnv1a(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x1_0000_0000_01b3
        }
        return hash
    }

    /// Deterministic PRNG (SplitMix64) — the system generators cannot be seeded.
    struct SplitMix64 {
        var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9e37_79b9_7f4a_7c15
            var z = state
            z = (z ^ (z >> 30)) &* 0xbf58_476d_1ce4_e5b9
            z = (z ^ (z >> 27)) &* 0x94d0_49bb_1331_11eb
            return z ^ (z >> 31)
        }

        /// Uniform value in 0..<1.
        mutating func unit() -> Double {
            Double(next() >> 11) / Double(1 << 53)
        }
    }
}
