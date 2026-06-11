import Foundation
import Testing
@testable import Breathwave

struct ToneProgramTests {
    @Test func breathingProgramMirrorsProtocolPhases() {
        let program = ToneProgram.breathing(.box)
        #expect(program.segments.count == 4)
        #expect(program.segments.map(\.duration) == [4, 4, 4, 4])
        #expect(program.cycleDuration == 16)
    }

    @Test func zeroPhasesProduceNoSegments() {
        let program = ToneProgram.breathing(.coherent)
        #expect(program.segments.count == 2)
        #expect(program.cycleDuration == 11)
    }

    @Test func frequencyIsContinuousAcrossSegments() {
        let program = ToneProgram.breathing(.box)
        for index in 0..<(program.segments.count - 1) {
            #expect(program.segments[index].endFrequency == program.segments[index + 1].startFrequency)
        }
        // ...and across the cycle wrap.
        #expect(program.segments.last?.endFrequency == program.segments.first?.startFrequency)
    }

    @Test func holdsAreSilent() {
        let program = ToneProgram.breathing(.box)
        #expect(program.segments[1].amplitude == 0)
        #expect(program.segments[3].amplitude == 0)
    }

    @Test func valueMidInhaleGlidesUpAtFullAmplitude() {
        let program = ToneProgram.breathing(.box)
        let value = program.value(at: 2)
        let midFrequency = (ToneProgram.lowFrequency + ToneProgram.highFrequency) / 2
        #expect(abs(value.frequency - midFrequency) < 1e-9)
        #expect(abs(value.amplitude - ToneProgram.breathingAmplitude) < 1e-9)
    }

    @Test func valueFadesInAtSegmentStart() {
        let program = ToneProgram.breathing(.box)
        let value = program.value(at: 0.05)
        #expect(value.amplitude > 0)
        #expect(value.amplitude < ToneProgram.breathingAmplitude)
    }

    @Test func valueIsSilentDuringHold() {
        let program = ToneProgram.breathing(.box)
        #expect(program.value(at: 6).amplitude == 0)
    }

    @Test func valueWrapsAroundCycle() {
        let program = ToneProgram.breathing(.box)
        let first = program.value(at: 2)
        let wrapped = program.value(at: 18)
        #expect(abs(first.frequency - wrapped.frequency) < 1e-9)
        #expect(abs(first.amplitude - wrapped.amplitude) < 1e-9)
    }

    @Test func emptyProgramIsSilent() {
        let program = ToneProgram(segments: [])
        let value = program.value(at: 5)
        #expect(value.amplitude == 0)
    }
}
