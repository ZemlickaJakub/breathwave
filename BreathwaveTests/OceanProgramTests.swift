import Foundation
import Testing
@testable import Breathwave

struct OceanProgramTests {
    @Test func breathingProgramMirrorsProtocolPhases() {
        let program = OceanProgram.breathing(.box)
        #expect(program.segments.count == 4)
        #expect(program.segments.map(\.duration) == [4, 4, 4, 4])
        #expect(program.cycleDuration == 16)
    }

    @Test func zeroPhasesProduceNoSegments() {
        let program = OceanProgram.breathing(.coherent)
        #expect(program.segments.count == 2)
        #expect(program.cycleDuration == 11)
    }

    @Test func cutoffIsContinuousAcrossSegments() {
        let program = OceanProgram.breathing(.box)
        for index in 0..<(program.segments.count - 1) {
            #expect(program.segments[index].endCutoff == program.segments[index + 1].startCutoff)
        }
        // ...and across the cycle wrap.
        #expect(program.segments.last?.endCutoff == program.segments.first?.startCutoff)
    }

    @Test func holdsAreQuietButNotSilent() {
        let program = OceanProgram.breathing(.box)
        let holdIn = program.value(at: 6)
        let holdOut = program.value(at: 14)
        #expect(holdIn.amplitude > 0)
        #expect(holdIn.amplitude <= 0.2)
        #expect(holdOut.amplitude > 0)
        #expect(holdOut.amplitude <= 0.2)
    }

    @Test func surfSwellsThroughInhale() {
        let program = OceanProgram.breathing(.box)
        let early = program.value(at: 0.5)
        let mid = program.value(at: 2)
        let late = program.value(at: 3.5)
        #expect(early.amplitude < mid.amplitude)
        #expect(mid.amplitude < late.amplitude)
        #expect(early.cutoff < late.cutoff)
    }

    @Test func surfRecedesThroughExhale() {
        let program = OceanProgram.breathing(.box)
        let early = program.value(at: 8.5)
        let late = program.value(at: 11.5)
        #expect(early.amplitude > late.amplitude)
        #expect(early.cutoff > late.cutoff)
    }

    @Test func valueWrapsAroundCycle() {
        let program = OceanProgram.breathing(.box)
        let first = program.value(at: 2)
        let wrapped = program.value(at: 18)
        #expect(abs(first.cutoff - wrapped.cutoff) < 1e-9)
        #expect(abs(first.amplitude - wrapped.amplitude) < 1e-9)
    }

    @Test func ambientIsSteady() {
        let program = OceanProgram.ambient()
        let a = program.value(at: 3)
        let b = program.value(at: 47)
        #expect(a.cutoff == b.cutoff)
        #expect(a.amplitude == b.amplitude)
        #expect(a.amplitude > 0)
    }

    @Test func emptyProgramIsSilent() {
        let program = OceanProgram(segments: [])
        #expect(program.value(at: 5).amplitude == 0)
    }

    @Test func breezeUsesHigherCutoffs() {
        let surf = OceanProgram.breathing(.box)
        let breeze = OceanProgram.breathing(.box, timbre: .breeze)
        #expect(breeze.timbre == .breeze)
        #expect(breeze.segments[0].startCutoff > surf.segments[0].startCutoff)
        #expect(breeze.segments[0].endCutoff > surf.segments[0].endCutoff)
    }

    @Test func ambientBreezeIsBrighterThanSurf() {
        let surf = OceanProgram.ambient()
        let breeze = OceanProgram.ambient(timbre: .breeze)
        #expect(breeze.value(at: 1).cutoff > surf.value(at: 1).cutoff)
        #expect(breeze.value(at: 1).amplitude == surf.value(at: 1).amplitude)
    }
}
