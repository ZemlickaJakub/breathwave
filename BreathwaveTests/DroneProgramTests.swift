import Foundation
import Testing
@testable import Breathwave

struct DroneProgramTests {
    @Test func omMirrorsProtocolPhases() {
        let program = DroneProgram.om(.om)
        #expect(program.segments.count == 2)
        #expect(program.cycleDuration == 16)
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
        let program = DroneProgram.om(.om)
        let early = program.value(at: 4.5)
        let late = program.value(at: 15.5)
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
