import AVFoundation
import os

/// Synthesizes ocean surf and a closing gong with AVAudioEngine.
/// The AVAudioSession is active only while a session runs (review 2.5.4);
/// the `audio` background mode keeps the session — and the app — alive
/// with the screen off, even when the program renders silence.
@MainActor
final class AudioEngine {
    private struct RenderState: Sendable {
        var program: OceanProgram?
        /// Seconds already practiced when the program (re)started — resume offset.
        var programOffset: Double = 0
        /// Sample index when the program (re)started; nil = capture on next render.
        var programStartSample: Double?
        var gongRequested = false
        var gongVolume: Double = 1
        var gongStartSample: Double?
        var sampleTime: Double = 0
        // Surf synthesis state.
        var noiseSeed: UInt64 = 0x9E3779B97F4A7C15
        var brown: Double = 0
        var lowPassed: Double = 0
        var slowSwell: Double = 0
        var currentAmplitude: Double = 0
        var currentCutoff: Double = OceanProgram.lowCutoff
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

    /// Activates the audio session and starts rendering `program`.
    /// Pass nil to render silence — that still keeps the app running in
    /// the background, which the session timer relies on.
    func startSession(program: OceanProgram?) {
        do {
            try activateIfNeeded()
            state.withLock {
                $0.program = program
                $0.programOffset = 0
                $0.programStartSample = nil
            }
        } catch {
            logger.error("Audio start failed: \(error)")
        }
    }

    /// Silences the surf (short amplitude slew, no click); session stays active.
    func pauseProgram() {
        state.withLock { $0.program = nil }
    }

    func resumeProgram(_ program: OceanProgram?, at elapsed: TimeInterval) {
        state.withLock {
            $0.program = program
            $0.programOffset = elapsed
            $0.programStartSample = nil
        }
    }

    /// One gong strike; volume < 1 gives a softer interval bell.
    func playGong(volume: Double = 1) {
        guard isSessionActive else { return }
        state.withLock {
            $0.gongRequested = true
            $0.gongVolume = volume
        }
    }

    /// Plays the closing gong and tears the session down once it fades out.
    func finishSession() {
        guard isSessionActive else { return }
        state.withLock { $0.program = nil }
        playGong()
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
        // Per-sample smoothing coefficients (single-pole, time constants in seconds).
        let amplitudeSlew = 1 / (0.35 * sampleRate)
        let cutoffSlew = 1 / (0.15 * sampleRate)
        let swellSlew = 2 * Double.pi * 0.15 / sampleRate

        return AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            state.withLock { renderState in
                for frame in 0..<Int(frameCount) {
                    // White noise via xorshift64.
                    renderState.noiseSeed ^= renderState.noiseSeed << 13
                    renderState.noiseSeed ^= renderState.noiseSeed >> 7
                    renderState.noiseSeed ^= renderState.noiseSeed << 17
                    let white = Double(renderState.noiseSeed >> 11) / Double(UInt64(1) << 53) * 2 - 1

                    // Surf targets from the program.
                    var targetCutoff = OceanProgram.lowCutoff
                    var targetAmplitude = 0.0
                    if let program = renderState.program {
                        if renderState.programStartSample == nil {
                            renderState.programStartSample = renderState.sampleTime
                        }
                        let start = renderState.programStartSample ?? renderState.sampleTime
                        let time = (renderState.sampleTime - start) / sampleRate + renderState.programOffset
                        let value = program.value(at: time)
                        targetCutoff = value.cutoff
                        targetAmplitude = value.amplitude
                    }
                    renderState.currentAmplitude += (targetAmplitude - renderState.currentAmplitude) * amplitudeSlew
                    renderState.currentCutoff += (targetCutoff - renderState.currentCutoff) * cutoffSlew

                    // Deep rumble: leaky-integrated (brown) noise.
                    renderState.brown = (renderState.brown + white * 0.02) * 0.999
                    // Foam hiss: white noise through the swelling low-pass.
                    let alpha = min(0.95, 2 * .pi * renderState.currentCutoff / sampleRate)
                    renderState.lowPassed += (white - renderState.lowPassed) * alpha
                    // Slow random swell so consecutive waves never sound identical.
                    renderState.slowSwell += (white - renderState.slowSwell) * swellSlew
                    let swell = 1 + max(-0.35, min(0.35, renderState.slowSwell * 60))

                    var sample = (renderState.brown * 0.7 + renderState.lowPassed * 0.5)
                        * renderState.currentAmplitude * swell * 0.9

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
                                    * attack * 0.7 * renderState.gongVolume
                            }
                        }
                    }

                    // Soft clip as a safety limiter.
                    let value = Float(tanh(sample))
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
