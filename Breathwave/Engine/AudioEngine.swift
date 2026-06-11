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
        var gongVoice: GongVoice = .bowl
        var gongStartSample: Double?
        var sampleTime: Double = 0
        // Timbre mix gains (surf: deep rumble; breeze: airy hiss).
        var rumbleGain: Double = 0.7
        var hissGain: Double = 0.5
        /// Depth of the slow random swell — breeze keeps it shallow (no gusts).
        var swellDepth: Double = 0.35
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

    /// One synthesized gong character: partials, mallet attack, beating depth.
    struct GongVoice: Sendable {
        var partials: [(frequency: Double, amplitude: Double, decay: Double)]
        var attack: Double
        var beatDepth: Double
        var master: Double
        var duration: TimeInterval

        /// Warm singing bowl: hums rather than clangs, long ring-out.
        nonisolated static let bowl = GongVoice(
            partials: [(220, 0.50, 8.0), (440.5, 0.20, 5.0), (587, 0.07, 2.5), (880, 0.03, 1.2)],
            attack: 0.15, beatDepth: 0.18, master: 0.5, duration: 8
        )

        /// Short gentle chime — a quiet high "ting".
        nonisolated static let chime = GongVoice(
            partials: [(1046.5, 0.35, 2.2), (2093, 0.12, 1.2), (2637, 0.06, 0.8), (3520, 0.03, 0.5)],
            attack: 0.03, beatDepth: 0.05, master: 0.4, duration: 4
        )

        /// Synthesized fallback used only when the bundled sample is missing.
        nonisolated static func voice(for sound: GongSound) -> GongVoice {
            switch sound {
            case .chime: .chime
            case .zenBowl: .bowl
            }
        }
    }

    private let logger = Logger(subsystem: "cz.jakubzemlicka.breathwave", category: "AudioEngine")
    private let avEngine = AVAudioEngine()
    private let state = OSAllocatedUnfairLock(initialState: RenderState())
    private var isConfigured = false
    private(set) var isSessionActive = false

    // Sample-based gongs, loaded from the bundle when present.
    private var samplePlayer: AVAudioPlayerNode?
    private var sampleBuffers: [GongSound: AVAudioPCMBuffer] = [:]
    private var sampleDurations: [GongSound: TimeInterval] = [:]
    private var currentGongSound: GongSound = .zenBowl

    // MARK: - Session control

    /// Activates the audio session and starts rendering. Both programs nil
    /// renders silence — that still keeps the app running in the background,
    /// which the session timer relies on.
    func startSession(program: OceanProgram?, drone: DroneProgram? = nil, gongSound: GongSound = .zenBowl) {
        do {
            try activateIfNeeded()
            currentGongSound = gongSound
            let voice = GongVoice.voice(for: gongSound)
            state.withLock {
                $0.program = program
                $0.programOffset = 0
                $0.programStartSample = nil
                $0.droneProgram = drone
                $0.droneOffset = 0
                $0.droneStartSample = nil
                $0.gongVoice = voice
                Self.applyTimbre(of: program, to: &$0)
            }
        } catch {
            logger.error("Audio start failed: \(error)")
        }
    }

    private nonisolated static func applyTimbre(of program: OceanProgram?, to renderState: inout RenderState) {
        switch program?.timbre {
        case .breeze:
            renderState.rumbleGain = 0.3
            renderState.hissGain = 0.32
            renderState.swellDepth = 0.15
        case .surf, nil:
            renderState.rumbleGain = 0.7
            renderState.hissGain = 0.5
            renderState.swellDepth = 0.35
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
            Self.applyTimbre(of: program, to: &$0)
        }
    }

    /// One gong strike; volume < 1 gives a softer interval bell.
    func playGong(volume: Double = 1) {
        guard isSessionActive else { return }
        if let samplePlayer, let buffer = sampleBuffers[currentGongSound] {
            samplePlayer.volume = Float(volume)
            samplePlayer.stop()
            samplePlayer.scheduleBuffer(buffer, at: nil)
            samplePlayer.play()
            return
        }
        state.withLock {
            $0.gongRequested = true
            $0.gongVolume = volume
        }
    }

    /// Plays the closing gong and tears the session down once it rings out.
    func finishSession() {
        guard isSessionActive else { return }
        var ringOut = state.withLock {
            $0.program = nil
            $0.droneProgram = nil
            return $0.gongVoice.duration
        }
        if let sampleDuration = sampleDurations[currentGongSound] {
            // Let the recording ring out fully before the session closes.
            ringOut = min(sampleDuration + 0.5, 30)
        }
        playGong()
        Task {
            try? await Task.sleep(for: .seconds(ringOut))
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
        samplePlayer?.stop()
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
        loadGongSamples()
    }

    /// Loads the bundled gong samples (Resources/Sounds/gong-*.m4a).
    private func loadGongSamples() {
        var sharedFormat: AVAudioFormat?
        for sound in GongSound.allCases {
            guard let url = sound.sampleURL else { continue }
            do {
                let file = try AVAudioFile(forReading: url)
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ) else { continue }
                try file.read(into: buffer)
                sampleBuffers[sound] = buffer
                sampleDurations[sound] = Double(file.length) / file.processingFormat.sampleRate
                sharedFormat = file.processingFormat
            } catch {
                logger.error("Gong sample \(sound.rawValue) failed to load: \(error)")
            }
        }
        guard let sharedFormat, !sampleBuffers.isEmpty else { return }
        let player = AVAudioPlayerNode()
        avEngine.attach(player)
        avEngine.connect(player, to: avEngine.mainMixerNode, format: sharedFormat)
        samplePlayer = player
    }

    // MARK: - Realtime rendering

    private nonisolated static func makeSourceNode(
        state: OSAllocatedUnfairLock<RenderState>,
        sampleRate: Double
    ) -> AVAudioSourceNode {
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
                    let depth = renderState.swellDepth
                    let swell = 1 + max(-depth, min(depth, renderState.slowSwell * 60))

                    var sample = (renderState.brown * renderState.rumbleGain
                        + renderState.lowPassed * renderState.hissGain)
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
                        let voice = renderState.gongVoice
                        let time = (renderState.sampleTime - gongStart) / sampleRate
                        if time > voice.duration + 1 {
                            renderState.gongStartSample = nil
                        } else {
                            // Soft mallet swell — warmed, not struck.
                            let attack = min(1, time / voice.attack)
                            for (index, partial) in voice.partials.enumerated() {
                                renderState.gongPhases[index] += 2 * .pi * partial.frequency / sampleRate
                                // Slow per-partial beating — the characteristic bowl shimmer.
                                let beat = 1 + voice.beatDepth * sin(2 * .pi * (0.5 + 0.25 * Double(index)) * time + Double(index) * 1.3)
                                sample += sin(renderState.gongPhases[index])
                                    * partial.amplitude
                                    * exp(-time / partial.decay)
                                    * attack * beat * voice.master * renderState.gongVolume
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
