import AVFoundation
import os

/// Synthesizes ocean surf, an om drone and a gentle chime with AVAudioEngine.
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
        var gongVoice: GongVoice = .chime
        var gongStartSample: Double?
        var sampleTime: Double = 0
        // Timbre mix gains (surf: deep rumble; breeze: whistling wind; breath: band-passed air).
        var rumbleGain: Double = 0.7
        var hissGain: Double = 0.5
        var bandGain: Double = 0
        var lowPassedNarrow: Double = 0
        /// Depth of the slow random swell — breeze uses it for gusts.
        var swellDepth: Double = 0.35
        // Resonant band (state-variable filter): wind whistle / breath formant.
        var resoGain: Double = 0
        /// SVF damping (1/Q): low = narrow whistle, high = broad airy formant.
        var resoDamping: Double = 1
        var svfLow: Double = 0
        var svfBand: Double = 0
        // Fixed vocal-tract formants — the human quality of the breath timbre.
        var formantGain: Double = 0
        var f1Low: Double = 0
        var f1Band: Double = 0
        var f2Low: Double = 0
        var f2Band: Double = 0
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

        /// Short gentle chime — a quiet high "ting".
        nonisolated static let chime = GongVoice(
            partials: [(1046.5, 0.35, 2.2), (2093, 0.12, 1.2), (2637, 0.06, 0.8), (3520, 0.03, 0.5)],
            attack: 0.03, beatDepth: 0.05, master: 0.4, duration: 4
        )

        /// Synthesized fallback used only when the bundled sample is missing.
        nonisolated static func voice(for sound: GongSound) -> GongVoice {
            switch sound {
            case .chime, .off: .chime  // .off never plays — guarded in playGong
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
    private var currentGongSound: GongSound = .chime

    // Looping meditation soundtrack (Resources/Sounds/ambient-meditation.*).
    // When bundled it replaces the synthesized ambient surf in the timer.
    private var ambientPlayer: AVAudioPlayerNode?
    private var ambientBuffer: AVAudioPCMBuffer?

    // Sample-based breath (Resources/Sounds/breath-inhale.*, breath-exhale.*).
    // When the recordings are bundled they replace the synthesized breath;
    // without them the synthesis stays as the fallback.
    private var breathPlayer: AVAudioPlayerNode?
    private var breathBuffers: [BreathPhase: AVAudioPCMBuffer] = [:]
    /// Phases driven by the bundled recordings; empty = synthesized fallback.
    private var breathSamplePhases: Set<BreathPhase> = []
    /// Phase-length variants of the breath samples, keyed by phase and
    /// duration in tenths of a second. A protocol only has a handful of
    /// distinct durations, so this stays tiny.
    private var trimmedBreathCache: [String: AVAudioPCMBuffer] = [:]
    /// In-flight volume ramp that quiets a still-ringing bell; cancelled
    /// whenever a new sample starts so the ramp never fights the playback.
    private var breathFadeTask: Task<Void, Never>?

    // MARK: - Session control

    /// Activates the audio session and starts rendering. Both programs nil
    /// renders silence — that still keeps the app running in the background,
    /// which the session timer relies on.
    func startSession(program: OceanProgram?, drone: DroneProgram? = nil, gongSound: GongSound = .chime) {
        do {
            try activateIfNeeded()
            currentGongSound = gongSound
            let voice = GongVoice.voice(for: gongSound)
            let program = resolveBreathSamples(for: resolveAmbientSample(for: program), drone: drone)
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

    /// Starts or stops the looping recorded soundtrack for the meditation
    /// timer; when it plays, the synthesized ambient is silenced (nil).
    private func resolveAmbientSample(for program: OceanProgram?) -> OceanProgram? {
        guard let ambientPlayer else { return program }
        if let program, program.isAmbient, let ambientBuffer {
            ambientPlayer.stop()
            ambientPlayer.scheduleBuffer(ambientBuffer, at: nil, options: .loops)
            ambientPlayer.volume = 0.6
            ambientPlayer.play()
            return nil
        }
        ambientPlayer.stop()
        return program
    }

    /// Bundled breath recordings take over from the synthesized program:
    /// the synth goes fully silent (any murmur bed reads as background
    /// noise under the clean bells) and `playBreathPhase` drives the
    /// samples. Om training (drone set, no ocean program) keeps the
    /// drone for the exhale and cues the inhale with the recorded bell —
    /// without it the inhale would be dead silent.
    private func resolveBreathSamples(for program: OceanProgram?, drone: DroneProgram?) -> OceanProgram? {
        if program?.timbre == .breath, !breathBuffers.isEmpty {
            breathSamplePhases = [.inhale, .exhale]
            return nil
        }
        if program == nil, drone != nil, !breathBuffers.isEmpty {
            breathSamplePhases = [.inhale]
            return nil
        }
        breathSamplePhases = []
        breathPlayer?.stop()
        return program
    }

    private nonisolated static func applyTimbre(of program: OceanProgram?, to renderState: inout RenderState) {
        switch program?.timbre {
        case .breeze:
            // Wind: no ocean rumble — a narrow whistling resonance that drifts
            // with the gusts, over a light airy hiss.
            renderState.rumbleGain = 0.06
            renderState.hissGain = 0.16
            renderState.bandGain = 0
            renderState.resoGain = 0.2
            renderState.resoDamping = 0.18
            renderState.formantGain = 0
            renderState.swellDepth = 0.65
        case .breath:
            // Breath: air shaped by fixed vocal-tract formants. No drifting
            // resonance (that is wind), no gusts — a steady human "haa".
            renderState.rumbleGain = 0
            renderState.hissGain = 0.08
            renderState.bandGain = 0.3
            renderState.resoGain = 0
            renderState.resoDamping = 1
            renderState.formantGain = 0.55
            renderState.swellDepth = 0.03
        case .surf, nil:
            renderState.rumbleGain = 0.7
            renderState.hissGain = 0.5
            renderState.bandGain = 0
            renderState.resoGain = 0
            renderState.resoDamping = 1
            renderState.formantGain = 0
            renderState.swellDepth = 0.35
        }
    }

    /// Silences surf and drone (short amplitude slew, no click); session stays active.
    func pauseProgram() {
        fadeOutBreathPlayer(over: 0.4)
        ambientPlayer?.stop()
        state.withLock {
            $0.program = nil
            $0.droneProgram = nil
        }
    }

    func resumeProgram(_ program: OceanProgram?, drone: DroneProgram? = nil, at elapsed: TimeInterval) {
        let program = resolveBreathSamples(for: resolveAmbientSample(for: program), drone: drone)
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

    /// Plays the bundled recording for a breath phase. The bell rings out
    /// naturally (trimmed only when it would bleed past the phase plus the
    /// following hold). Holds duck the ring to a soft level — audible but
    /// gentle, like the ocean murmur. Other phases without a sample (the om
    /// exhale) gently fade out whatever is still ringing — never a hard cut.
    /// No-op while the synthesized fallback is active.
    func playBreathPhase(_ phase: BreathPhase, duration: TimeInterval) {
        guard isSessionActive, !breathSamplePhases.isEmpty, let breathPlayer else { return }
        guard breathSamplePhases.contains(phase) else {
            if phase == .holdAfterInhale || phase == .holdAfterExhale {
                duckBreathPlayer(to: 0.35)
                return
            }
            fadeOutBreathPlayer()
            return
        }
        guard let buffer = trimmedBreathBuffer(for: phase, duration: duration) else { return }
        breathFadeTask?.cancel()
        breathPlayer.stop()
        breathPlayer.volume = 1
        breathPlayer.scheduleBuffer(buffer, at: nil)
        breathPlayer.play()
    }

    /// Ramps the breath player down, then stops it. An abrupt `stop()`
    /// mid-ring is clearly audible; this is not. The slow default overlaps
    /// the om swell-in so bell and om crossfade into one ambient texture.
    private func fadeOutBreathPlayer(over duration: TimeInterval = 1.5) {
        guard let breathPlayer, breathPlayer.isPlaying else { return }
        breathFadeTask?.cancel()
        breathFadeTask = Task {
            let steps = max(4, Int(duration / 0.025))
            let start = breathPlayer.volume
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(25))
                if Task.isCancelled { return }
                breathPlayer.volume = start * (1 - Float(step) / Float(steps))
            }
            breathPlayer.stop()
            breathPlayer.volume = 1
        }
    }

    /// Eases the ringing bell down to a quiet level without stopping it,
    /// so holds keep a soft, audible tail instead of a full-volume ring.
    private func duckBreathPlayer(to target: Float, over duration: TimeInterval = 0.6) {
        guard let breathPlayer, breathPlayer.isPlaying else { return }
        breathFadeTask?.cancel()
        breathFadeTask = Task {
            let steps = max(4, Int(duration / 0.025))
            let start = breathPlayer.volume
            guard start > target else { return }
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(25))
                if Task.isCancelled { return }
                breathPlayer.volume = start + (target - start) * Float(step) / Float(steps)
            }
        }
    }

    /// Looping a tonal, decaying bell produces audible seams, so the
    /// recording is never stretched — it plays as recorded and is trimmed
    /// with a fade only when it would outlast the phase plus its hold.
    private func trimmedBreathBuffer(for phase: BreathPhase, duration: TimeInterval) -> AVAudioPCMBuffer? {
        guard let source = breathBuffers[phase] else { return nil }
        let key = "\(phase.rawValue)-\(Int(duration * 10))"
        if let cached = trimmedBreathCache[key] { return cached }
        guard let buffer = Self.truncated(source, target: duration) else { return source }
        trimmedBreathCache[key] = buffer
        return buffer
    }

    /// Fades the last `seconds` of a buffer to silence in place, so a
    /// recording that ends mid-ring lands on zero instead of clicking.
    private static func fadeTail(of buffer: AVAudioPCMBuffer, seconds: TimeInterval) {
        let frames = Int(buffer.frameLength)
        let fadeFrames = min(Int(seconds * buffer.format.sampleRate), frames)
        guard fadeFrames > 0, let data = buffer.floatChannelData else { return }
        for channel in 0..<Int(buffer.format.channelCount) {
            for i in 0..<fadeFrames {
                let t = Float(i) / Float(fadeFrames)
                data[channel][frames - 1 - i] *= sin(t * .pi / 2)
            }
        }
    }

    /// Shortens a recording to `target` seconds with a 0.4 s fade-out.
    /// Returns nil when the recording already fits.
    private static func truncated(_ source: AVAudioPCMBuffer, target: TimeInterval) -> AVAudioPCMBuffer? {
        let sampleRate = source.format.sampleRate
        let targetFrames = Int(target * sampleRate)
        guard targetFrames > 0, targetFrames < Int(source.frameLength),
              let sourceData = source.floatChannelData?[0],
              let out = AVAudioPCMBuffer(pcmFormat: source.format, frameCapacity: AVAudioFrameCount(targetFrames)),
              let outData = out.floatChannelData?[0] else { return nil }
        out.frameLength = AVAudioFrameCount(targetFrames)
        outData.update(from: sourceData, count: targetFrames)
        let fadeFrames = min(Int(0.4 * sampleRate), targetFrames)
        for i in 0..<fadeFrames {
            let t = Float(i) / Float(fadeFrames)
            outData[targetFrames - 1 - i] *= sin(t * .pi / 2)
        }
        return out
    }

    /// One gong strike; volume < 1 gives a softer interval bell.
    func playGong(volume: Double = 1) {
        guard isSessionActive, currentGongSound != .off else { return }
        // The format check guards against a bundled sample whose channel
        // layout differs from the player's connection — scheduling such a
        // buffer raises NSException and would crash the app.
        if let samplePlayer, let buffer = sampleBuffers[currentGongSound] {
            if buffer.format == samplePlayer.outputFormat(forBus: 0) {
                samplePlayer.volume = Float(volume)
                samplePlayer.stop()
                samplePlayer.scheduleBuffer(buffer, at: nil)
                samplePlayer.play()
                return
            }
            logger.error("Gong sample \(self.currentGongSound.rawValue) format mismatch — using synthesized gong")
        }
        state.withLock {
            $0.gongRequested = true
            $0.gongVolume = volume
        }
    }

    /// Plays the closing gong and tears the session down once it rings out.
    func finishSession() {
        guard isSessionActive else { return }
        guard currentGongSound != .off else {
            deactivate()
            return
        }
        var ringOut = state.withLock {
            $0.program = nil
            $0.droneProgram = nil
            return $0.gongVoice.duration
        }
        fadeOutBreathPlayer()
        ambientPlayer?.stop()
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
        breathFadeTask?.cancel()
        breathPlayer?.stop()
        ambientPlayer?.stop()
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
        loadBreathSamples()
        loadAmbientSample()
    }

    /// Loads the optional meditation soundtrack (Resources/Sounds/ambient-meditation.*).
    private func loadAmbientSample() {
        guard let url = Self.bundledSoundURL(named: "ambient-meditation") else { return }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: AVAudioFrameCount(file.length)
            ) else { return }
            try file.read(into: buffer)
            ambientBuffer = buffer
            let player = AVAudioPlayerNode()
            avEngine.attach(player)
            avEngine.connect(player, to: avEngine.mainMixerNode, format: file.processingFormat)
            ambientPlayer = player
        } catch {
            logger.error("Ambient sample failed to load: \(error)")
        }
    }

    /// Loads the optional breath recordings (Resources/Sounds/breath-*.m4a).
    private func loadBreathSamples() {
        let names: [BreathPhase: String] = [.inhale: "breath-inhale", .exhale: "breath-exhale"]
        var sharedFormat: AVAudioFormat?
        for (phase, name) in names {
            guard let url = Self.bundledSoundURL(named: name) else { continue }
            do {
                let file = try AVAudioFile(forReading: url)
                guard let buffer = AVAudioPCMBuffer(
                    pcmFormat: file.processingFormat,
                    frameCapacity: AVAudioFrameCount(file.length)
                ) else { continue }
                try file.read(into: buffer)
                // Both recordings stop while the bell is still ringing —
                // unfaded, the cut is an audible "tink" at the end.
                Self.fadeTail(of: buffer, seconds: 1.5)
                breathBuffers[phase] = buffer
                sharedFormat = file.processingFormat
            } catch {
                logger.error("Breath sample \(name) failed to load: \(error)")
            }
        }
        guard let sharedFormat, !breathBuffers.isEmpty else { return }
        let player = AVAudioPlayerNode()
        avEngine.attach(player)
        avEngine.connect(player, to: avEngine.mainMixerNode, format: sharedFormat)
        breathPlayer = player
    }

    nonisolated private static func bundledSoundURL(named name: String) -> URL? {
        for ext in ["caf", "wav", "m4a", "aiff", "mp3"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                return url
            }
        }
        return nil
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
        // Fixed formant coefficients for the breath timbre — roughly the
        // first two resonances of a relaxed male vocal tract.
        let formant1F = 2 * sin(.pi * 520 / sampleRate)
        let formant2F = 2 * sin(.pi * 1350 / sampleRate)

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
                    // Narrow companion filter; the difference gives band-passed
                    // "air" for the breath timbre.
                    renderState.lowPassedNarrow += (white - renderState.lowPassedNarrow) * (alpha * 0.25)
                    let bandPassed = renderState.lowPassed - renderState.lowPassedNarrow
                    // Slow random swell so consecutive waves never sound identical.
                    renderState.slowSwell += (white - renderState.slowSwell) * swellSlew
                    let depth = renderState.swellDepth
                    let swell = 1 + max(-depth, min(depth, renderState.slowSwell * 60))

                    // Resonant band (SVF on white noise): the whistle of wind,
                    // the formant of breath. The center frequency follows the
                    // program cutoff and drifts with the gusts, so wind pitch
                    // rises and falls as it swells.
                    var resonant = 0.0
                    if renderState.resoGain > 0 {
                        let center = min(4000, renderState.currentCutoff * swell)
                        let f = 2 * sin(.pi * center / sampleRate)
                        renderState.svfLow += f * renderState.svfBand
                        let high = white - renderState.svfLow
                            - renderState.resoDamping * renderState.svfBand
                        renderState.svfBand += f * high
                        resonant = renderState.svfBand
                    }

                    // Fixed vocal-tract formants (breath only): noise shaped
                    // by an unmoving throat and mouth reads as human, while a
                    // drifting resonance reads as wind. The exhale leans on
                    // the low "haa" formant, the inhale on brightness.
                    var formants = 0.0
                    if renderState.formantGain > 0 {
                        renderState.f1Low += formant1F * renderState.f1Band
                        let high1 = white - renderState.f1Low - 0.5 * renderState.f1Band
                        renderState.f1Band += formant1F * high1
                        renderState.f2Low += formant2F * renderState.f2Band
                        let high2 = white - renderState.f2Low - 0.7 * renderState.f2Band
                        renderState.f2Band += formant2F * high2
                        let brightness = max(0, min(1, (renderState.currentCutoff - 600) / 1800))
                        formants = renderState.f1Band * (1.1 - 0.7 * brightness)
                            + renderState.f2Band * (0.5 + 0.3 * brightness)
                    }

                    var sample = (renderState.brown * renderState.rumbleGain
                        + renderState.lowPassed * renderState.hissGain
                        + bandPassed * renderState.bandGain
                        + resonant * renderState.resoGain
                        + formants * renderState.formantGain)
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
                        // Energy sits in the harmonics (260/390/520 Hz):
                        // the iPhone speaker barely reproduces the 130 Hz
                        // fundamental, so a fundamental-heavy mix is nearly
                        // inaudible without headphones.
                        sample += (sin(p) * 0.45 + sin(2 * p) * 0.40
                            + sin(3 * p) * 0.20 + sin(4 * p) * 0.10)
                            * renderState.droneAmplitude
                    }

                    // Chime strike (synthesized fallback).
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
