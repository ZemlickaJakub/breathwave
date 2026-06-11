import AVFoundation
import os

/// Synthesizes breathing tones and a closing gong with AVAudioEngine.
/// The AVAudioSession is active only while a session runs (review 2.5.4);
/// the `audio` background mode keeps guiding with the screen off.
@MainActor
final class AudioEngine {
    private struct RenderState: Sendable {
        var program: ToneProgram?
        /// Seconds already practiced when the program (re)started — resume offset.
        var programOffset: Double = 0
        /// Sample index when the program (re)started; nil = capture on next render.
        var programStartSample: Double?
        var gongRequested = false
        var gongStartSample: Double?
        var sampleTime: Double = 0
        var tonePhase: Double = 0
        var currentAmplitude: Double = 0
        var gongPhases: [Double] = [0, 0, 0, 0]
    }

    /// Bell-like partials: slightly inharmonic overtones with individual decay.
    private nonisolated static let gongPartials: [(frequency: Double, amplitude: Double, decay: Double)] = [
        (220, 0.45, 2.6),
        (446, 0.22, 1.9),
        (664, 0.12, 1.3),
        (1126, 0.06, 0.8),
    ]
    private nonisolated static let gongDuration: TimeInterval = 5

    private let logger = Logger(subsystem: "cz.jakubzemlicka.breathwave", category: "AudioEngine")
    private let avEngine = AVAudioEngine()
    private let state = OSAllocatedUnfairLock(initialState: RenderState())
    private var isConfigured = false
    private(set) var isSessionActive = false

    // MARK: - Session control

    func startBreathing(_ breathingProtocol: BreathingProtocol) {
        do {
            try activateIfNeeded()
            state.withLock {
                $0.program = ToneProgram.breathing(breathingProtocol)
                $0.programOffset = 0
                $0.programStartSample = nil
            }
        } catch {
            logger.error("Audio start failed: \(error)")
        }
    }

    /// Silences the tones (short amplitude slew, no click); session stays active.
    func pauseTones() {
        state.withLock { $0.program = nil }
    }

    func resumeTones(_ breathingProtocol: BreathingProtocol, at elapsed: TimeInterval) {
        state.withLock {
            $0.program = ToneProgram.breathing(breathingProtocol)
            $0.programOffset = elapsed
            $0.programStartSample = nil
        }
    }

    /// Plays the closing gong and tears the session down once it fades out.
    func finishSession() {
        guard isSessionActive else { return }
        state.withLock {
            $0.program = nil
            $0.gongRequested = true
        }
        Task {
            try? await Task.sleep(for: .seconds(Self.gongDuration))
            self.deactivate()
        }
    }

    /// Immediate teardown without the gong (user leaves mid-session).
    func deactivate() {
        guard isSessionActive else { return }
        state.withLock {
            $0.program = nil
            $0.gongRequested = false
            $0.gongStartSample = nil
        }
        avEngine.stop()
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Audio session deactivation failed: \(error)")
        }
        isSessionActive = false
    }

    // MARK: - Engine setup

    private func activateIfNeeded() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
        if !isConfigured {
            try configureGraph()
            isConfigured = true
        }
        if !avEngine.isRunning {
            try avEngine.start()
        }
        isSessionActive = true
    }

    private func configureGraph() throws {
        var sampleRate = avEngine.outputNode.outputFormat(forBus: 0).sampleRate
        if sampleRate <= 0 { sampleRate = 44_100 }
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false
        ) else {
            throw AVError(.unknown)
        }
        let source = Self.makeSourceNode(state: state, sampleRate: sampleRate)
        avEngine.attach(source)
        avEngine.connect(source, to: avEngine.mainMixerNode, format: format)
    }

    // MARK: - Realtime rendering

    private nonisolated static func makeSourceNode(
        state: OSAllocatedUnfairLock<RenderState>,
        sampleRate: Double
    ) -> AVAudioSourceNode {
        let partials = gongPartials
        let gongLimit = gongDuration + 1
        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            state.withLock { renderState in
                for frame in 0..<Int(frameCount) {
                    var sample = 0.0

                    // Breathing tone.
                    var frequency = ToneProgram.lowFrequency
                    var targetAmplitude = 0.0
                    if let program = renderState.program {
                        if renderState.programStartSample == nil {
                            renderState.programStartSample = renderState.sampleTime
                        }
                        let start = renderState.programStartSample ?? renderState.sampleTime
                        let time = (renderState.sampleTime - start) / sampleRate + renderState.programOffset
                        let value = program.value(at: time)
                        frequency = value.frequency
                        targetAmplitude = value.amplitude
                    }
                    // ~8 ms amplitude slew kills clicks on start/pause.
                    let maxStep = 1 / (0.008 * sampleRate)
                    let delta = targetAmplitude - renderState.currentAmplitude
                    renderState.currentAmplitude += max(-maxStep, min(maxStep, delta))
                    renderState.tonePhase += 2 * .pi * frequency / sampleRate
                    if renderState.tonePhase > 2 * .pi { renderState.tonePhase -= 2 * .pi }
                    sample += sin(renderState.tonePhase) * renderState.currentAmplitude

                    // Gong.
                    if renderState.gongRequested {
                        renderState.gongRequested = false
                        renderState.gongStartSample = renderState.sampleTime
                        renderState.gongPhases = [0, 0, 0, 0]
                    }
                    if let gongStart = renderState.gongStartSample {
                        let time = (renderState.sampleTime - gongStart) / sampleRate
                        if time > gongLimit {
                            renderState.gongStartSample = nil
                        } else {
                            let attack = min(1, time / 0.005)
                            for (index, partial) in partials.enumerated() {
                                renderState.gongPhases[index] += 2 * .pi * partial.frequency / sampleRate
                                sample += sin(renderState.gongPhases[index])
                                    * partial.amplitude
                                    * exp(-time / partial.decay)
                                    * attack * 0.7
                            }
                        }
                    }

                    let value = Float(sample)
                    for buffer in buffers {
                        guard let data = buffer.mData?.assumingMemoryBound(to: Float.self) else { continue }
                        data[frame] = value
                    }
                    renderState.sampleTime += 1
                }
            }
            return noErr
        }
    }
}
