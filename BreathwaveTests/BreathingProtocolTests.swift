import Foundation
import Testing
@testable import Breathwave

struct BreathingProtocolTests {
    @Test func cycleDurationSumsAllPhases() {
        #expect(BreathingProtocol.coherent.cycleDuration == 11)
        #expect(BreathingProtocol.box.cycleDuration == 16)
        #expect(BreathingProtocol.fourSevenEight.cycleDuration == 19)
        #expect(BreathingProtocol.extendedExhale.cycleDuration == 10)
    }

    @Test func zeroDurationPhasesAreSkipped() {
        #expect(BreathingProtocol.coherent.phases.map(\.phase) == [.inhale, .exhale])
        #expect(BreathingProtocol.fourSevenEight.phases.map(\.phase) == [.inhale, .holdAfterInhale, .exhale])
    }

    @Test func boxHasAllFourPhasesInBreathingOrder() {
        #expect(BreathingProtocol.box.phases.map(\.phase) == BreathPhase.allCases)
    }

    @Test func presetsHaveUniqueIDs() {
        let ids = BreathingProtocol.presets.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func codableRoundtrip() throws {
        let original = BreathingProtocol.box
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BreathingProtocol.self, from: data)
        #expect(decoded == original)
    }
}
