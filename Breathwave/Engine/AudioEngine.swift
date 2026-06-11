import AVFoundation
import os

/// Synthesizes ocean surf, an om drone and a singing-bowl gong with AVAudioEngine.
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
        var droneProgram: DroneProgram?
        var droneOffset: Double = 0
        var droneStartSample: Double?
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
        // Drone synthesis state.
        var dronePhase: Double = 0
        var droneAmplitude: Double = 0
        var gongPhases: [Double] = [0, 0, 0, 0]
    }

    /// Singing-bowl voice: low fundamental, slightly inharmonic overtones,
    /// long ring-out. Per-partial beating is added in the render loop.
    private nonisolated static let gongPartials: [(frequency: Double, amplitude: Double, decay: Double)] = [
        (220, 0.50, 7.0),
        (446, 0.25, 4.5),
        (586, 0.12, 3.0),
        (880, 0.05, 1.5),
    ]
    private nonisolated static let gongDuration: TimeInterval = 8

    private let logger = Logger(subsystem: "cz.jakubzemlicka.breathwave", category: "AudioEngine")
    private let avEngine = AVAudioEngine()
    private let state = OSAllocatedUnfairLock(initialState: RenderState())
    private var isConfigured = false
    private(set) var isSessionActive = false

    // MARK: - Session control

    /// Activates the audio session and starts rendering. Both programs nil
    /// renders silence — that still keeps the app running in the background,
    /// which the session timer relies on.
    func startSession(program: OceanProgram?, drone: DroneProgram? = nil) {
        do {
            try activateIfNeeded()
            state.withLock {
                $0.program = program
                $0.programOffset = 0
                $0.programStartSample = nil
                $0.droneProgram = drone
                $0.droneOffset = 0
                $0.droneStartSample = nil
            }
        } catch {
            logger.error("Audio start failed: \(error)")
        }
    }

    /// Silences surf and drone (short amplitude slew, no click); session stays active.
    func pauseProgram() {
        state.withLock {
            $0.program = nil
            $0.droneProgram = nil
        }
    }

    func resumeProgram(_ program: OceanProgram?, drone: DroneProgram? = nil, at elapsed: TimeInterval) {
        state.withLock {
            $0.program = program
            $0.programOffset = elapsed
            $0.programStartSample = nil
            $0.droneProgram = drone
            $0.droneOffset = elapsed
            $0.droneStartSample = nil
        }
    }

    /// One bowl strike; volume < 1 gives a softer interval bell.
    func playGong(volume: Double = 1) {
        guard isSessionActive else { return }
        state.withLock {
            $0.gongRequested = true
            $0.gongVolume = volume
        }
    }

    /// Plays the closing gong and tears the session down once it rings out.
    func finishSession() {
        guard isSessionActive else { return }
        state.withLock {
            $0.program = nil
            $0.droneProgram = nil
        }
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
            $0.droneProgram = nil
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
        let droneSlew = 1 / (0.2 * sampleRate)
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

                    // Om drone: warm tone with two soft harmonics and a touch of vibrato.
                    var droneTarget = 0.0
                    var droneFrequency = DroneProgram.omFrequency
                    if let drone = renderState.droneProgram {
                        if renderState.droneStartSample == nil {
                            renderState.droneStartSample = renderState.sampleTime
                        }
                        let start = renderState.droneStartSample ?? renderState.sampleTime
                        let time = (renderState.sampleTime - start) / sampleRate + renderState.droneOffset
                        let value = drone.value(at: time)
                        droneFrequency = value.frequency
                        droneTarget = value.amplitude
                    }
                    renderState.droneAmplitude += (droneTarget - renderState.droneAmplitude) * droneSlew
                    if renderState.droneAmplitude > 0.0005 {
                        let globalTime = renderState.sampleTime / sampleRate
                        let vibrato = 1 + 0.005 * sin(2 * .pi * 4.5 * globalTime)
                        renderState.dronePhase += 2 * .pi * droneFrequency * vibrato / sampleRate
                        if renderState.dronePhase > 2 * .pi { renderState.dronePhase -= 2 * .pi }
                        let p = renderState.dronePhase
                        sample += (sin(p) * 0.55 + sin(2 * p) * 0.22 + sin(3 * p) * 0.09)
                            * renderState.droneAmplitude
                    }

                    // Singing bowl.
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
                            // Soft mallet: 40 ms swell instead of a hard strike.
                            let attack = min(1, time / 0.04)
                            for (index, partial) in partials.enumerated() {
                                renderState.gongPhases[index] += 2 * .pi * partial.frequency / sampleRate
                                // Slow per-partial beating — the characteristic bowl shimmer.
                                let beat = 1 + 0.25 * sin(2 * .pi * (0.7 + 0.3 * Double(index)) * time + Double(index) * 1.3)
                                sample += sin(renderState.gongPhases[index])
                                    * partial.amplitude
                                    * exp(-time / partial.decay)
                                    * attack * beat * 0.55 * renderState.gongVolume
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
