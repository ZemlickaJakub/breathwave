import Foundation
import Testing
@testable import Breathwave

struct BloomParametersTests {
    private func makeSession(
        id: UUID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEFFFF0001")!,
        duration: TimeInterval = 300,
        kind: Session.Kind = .breathing(protocolID: "box")
    ) -> Session {
        Session(
            id: id,
            completedAt: Date(timeIntervalSince1970: 1_750_000_000),
            duration: duration,
            kind: kind
        )
    }

    @Test func sameSessionGrowsTheSameBloom() {
        let session = makeSession()
        #expect(BloomParameters.from(session) == BloomParameters.from(session))
    }

    @Test func differentSessionsGrowDifferentBlooms() {
        let first = makeSession(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEFFFF0001")!)
        let second = makeSession(id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEFFFF0002")!)
        #expect(BloomParameters.from(first) != BloomParameters.from(second))
    }

    @Test func longerPracticeGrowsFullerFlowers() {
        let short = BloomParameters.from(makeSession(duration: 60))
        let long = BloomParameters.from(makeSession(duration: 1200))
        #expect(short.petalCount < long.petalCount)
        #expect(short.layerCount < long.layerCount)
    }

    @Test func breathingAndMeditationUseDistinctHueBands() {
        let breathing = BloomParameters.from(makeSession(kind: .breathing(protocolID: "box")))
        let meditation = BloomParameters.from(makeSession(kind: .meditation))
        #expect(breathing.baseHue <= 0.60)
        #expect(meditation.baseHue >= 0.68)
    }

    @Test func parametersStayInRenderableRanges() {
        for duration: TimeInterval in [10, 300, 900, 3600] {
            for kind in [Session.Kind.breathing(protocolID: "coherent"), .meditation] {
                let params = BloomParameters.from(makeSession(duration: duration, kind: kind))
                #expect((6...12).contains(params.petalCount))
                #expect((2...3).contains(params.layerCount))
                #expect((0...1).contains(params.baseHue))
                #expect(params.petalAspect > 0.2 && params.petalAspect < 0.7)
                #expect(params.rotationOffset >= 0 && params.rotationOffset < 2 * .pi)
                #expect(params.petalWobble > 0 && params.petalWobble < 0.3)
            }
        }
    }

    @Test func seededGeneratorIsDeterministic() {
        var first = BloomParameters.SplitMix64(seed: 42)
        var second = BloomParameters.SplitMix64(seed: 42)
        for _ in 0..<10 {
            #expect(first.next() == second.next())
        }
    }
}
