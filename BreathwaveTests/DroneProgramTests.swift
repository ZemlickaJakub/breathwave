import Foundation
import Testing
@testable import Breathwave

struct DroneProgramTests {
    @Test func omMirrorsProtocolPhases() {
        // The exhale is split into delay + swell-in + sustain + release.
        let program = DroneProgram.om(.om)
        #expect(program.segments.count == 5)
        #expect(abs(program.cycleDuration - 16) < 1e-9)
    }

    @Test func omStaysSilentBrieflyAfterInhale() {
        // The short delay gives the lungs room to turn around.
        let program = DroneProgram.om(.om)
        #expect(program.value(at: 4.3).amplitude == 0)
    }

    @Test func omSwellsInAfterDelay() {
        let program = DroneProgram.om(.om)
        let onset = program.value(at: 5.5)
        let sustained = program.value(at: 8)
        #expect(onset.amplitude > 0)
        #expect(onset.amplitude < sustained.amplitude)
    }

    @Test func omReleasesBeforeExhaleEnds() {
        // The release ramps to silence right at the exhale boundary, so
        // the next inhale never lands mid-om.
        let program = DroneProgram.om(.om)
        let releasing = program.value(at: 15.5)
        let sustained = program.value(at: 12)
        #expect(releasing.amplitude < sustained.amplitude)
        #expect(program.value(at: 15.999).amplitude < 0.01)
    }

    @Test func droneIsSilentDuringInhale() {
        let program = DroneProgram.om(.om)
        #expect(program.value(at: 2).amplitude == 0)
    }

    @Test func droneIsVoicedDuringExhale() {
        let program = DroneProgram.om(.om)
        let value = program.value(at: 8)
        #expect(value.amplitude > 0)
        #expect(value.frequency == DroneProgram.omFrequency)
    }

    @Test func droneFadesSlightlyTowardExhaleEnd() {
        // Compare two points inside the sustain (after the swell-in,
        // before the release).
        let program = DroneProgram.om(.om)
        let early = program.value(at: 8)
        let late = program.value(at: 14)
        #expect(early.amplitude > late.amplitude)
    }

    @Test func valueWrapsAroundCycle() {
        let program = DroneProgram.om(.om)
        let first = program.value(at: 8)
        let wrapped = program.value(at: 24)
        #expect(abs(first.amplitude - wrapped.amplitude) < 1e-9)
    }

    @Test func holdsStaySilent() {
        let program = DroneProgram.om(.box)
        #expect(program.value(at: 6).amplitude == 0)   // hold after inhale
        #expect(program.value(at: 14).amplitude == 0)  // hold after exhale
    }

    @Test func emptyProgramIsSilent() {
        let program = DroneProgram(segments: [])
        #expect(program.value(at: 3).amplitude == 0)
    }
}
