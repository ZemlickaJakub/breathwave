import SwiftUI

struct BreathingSessionView: View {
    let breathingProtocol: BreathingProtocol

    @State private var engine = BreathingEngine()
    @State private var audio = AudioEngine()
    @State private var haptics = HapticsEngine()
    @State private var lastHapticPhase: BreathPhase?
    @State private var selectedMinutes: Int? = 5
    @State private var omExhaleSeconds = 12
    @State private var hasRecorded = false
    @State private var showsInfo = false
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings
    @Environment(HealthService.self) private var healthService
    @Environment(\.dismiss) private var dismiss

    /// Sessions shorter than this are treated as accidental and not recorded.
    private static let minimumRecordedDuration: TimeInterval = 30
    private static let durationChoices: [Int?] = [1, 3, 5, 10, 15, nil]
    private static let omExhaleChoices = [8, 10, 12, 15, 20]

    /// Om training adjusts the exhale length; everything else runs as-is.
    private var activeProtocol: BreathingProtocol {
        guard breathingProtocol.isOmTraining else { return breathingProtocol }
        var adjusted = breathingProtocol
        adjusted.exhale = TimeInterval(omExhaleSeconds)
        return adjusted
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            TimelineView(.animation) { context in
                VStack(spacing: 24) {
                    PacerView(
                        snapshot: engine.snapshot,
                        time: context.date.timeIntervalSinceReferenceDate,
                        exhaleLabel: breathingProtocol.isOmTraining ? "Om" : "Breathe Out"
                    )
                    Text(elapsedText)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if engine.state == .idle || engine.state == .finished {
                pickers
            }
            SessionControls(
                state: engine.state,
                onStart: startSession,
                onPause: pauseSession,
                onResume: resumeSession,
                onEnd: endSession
            )
        }
        .padding()
        .calmBackground()
        .navigationTitle(breathingProtocol.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsInfo = true
                } label: {
                    Label("About this exercise", systemImage: "info.circle")
                }
            }
        }
        .sheet(isPresented: $showsInfo) {
            ExerciseInfoSheet(
                title: breathingProtocol.localizedName,
                descriptionKey: breathingProtocol.descriptionKey,
                whenKey: breathingProtocol.whenKey,
                rhythm: activeProtocol.rhythmSummary
            )
        }
        .task(id: engine.state) { await runPhaseLoop() }
        .onDisappear { teardown() }
    }

    private var elapsedText: String {
        Duration.seconds(engine.elapsed).formatted(.time(pattern: .minuteSecond))
    }

    private var pickers: some View {
        VStack(spacing: 12) {
            if breathingProtocol.isOmTraining {
                HStack {
                    Text("Om length")
                    Spacer()
                    Picker("Om length", selection: $omExhaleSeconds) {
                        ForEach(Self.omExhaleChoices, id: \.self) { Text("\($0) s").tag($0) }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 8)
            }
            DurationPicker(minutes: $selectedMinutes, choices: Self.durationChoices)
        }
    }

    // MARK: - Session lifecycle

    private func startSession() {
        lastHapticPhase = nil
        hasRecorded = false
        if settings.hapticsEnabled { haptics.prepare() }
        engine.start(activeProtocol, duration: selectedMinutes.map { TimeInterval($0 * 60) })
        // A nil program renders silence but keeps the audio session — and the
        // app — alive in the background with the screen off.
        audio.startSession(
            program: breathingProgram,
            drone: droneProgram,
            gongSound: settings.gongSound
        )
    }

    /// Breath-synced surf; nil (silent render) when the breathing sound is
    /// off or in om training — the session still stays alive in the
    /// background either way.
    private var breathingProgram: OceanProgram? {
        guard !breathingProtocol.isOmTraining,
              let timbre = settings.breathSound.timbre else { return nil }
        return .breathing(activeProtocol, timbre: timbre)
    }

    /// Om drone; the breathing-sound Off switch silences it too.
    private var droneProgram: DroneProgram? {
        guard breathingProtocol.isOmTraining, settings.breathSound != .off else { return nil }
        return .om(activeProtocol)
    }

    private func pauseSession() {
        engine.pause()
        audio.pauseProgram()
    }

    private func resumeSession() {
        engine.resume()
        audio.resumeProgram(breathingProgram, drone: droneProgram, at: engine.elapsed)
    }

    private func endSession() {
        engine.finish()
        completeSession()
        dismiss()
    }

    private func completeSession() {
        guard !hasRecorded else { return }
        hasRecorded = true
        haptics.stop()
        // Bailing out early is a cancel: cut the audio, skip the closing gong.
        guard engine.elapsed >= Self.minimumRecordedDuration else {
            audio.deactivate()
            return
        }
        // finishSession skips the gong itself when the gong sound is off.
        audio.finishSession()
        let session = Session(
            completedAt: .now,
            duration: engine.elapsed,
            kind: .breathing(protocolID: breathingProtocol.id)
        )
        sessionStore.add(session)
        if settings.healthSyncEnabled {
            let healthService = self.healthService
            Task { await healthService.save(session) }
        }
    }

    private func teardown() {
        if engine.state == .running || engine.state == .paused {
            audio.deactivate()
        }
        haptics.stop()
        engine.reset()
    }

    /// Polls the engine while running: drives auto-finish and fires one
    /// haptic pattern per phase transition. The active audio session keeps
    /// this loop alive in the background.
    private func runPhaseLoop() async {
        guard engine.state == .running else { return }
        while !Task.isCancelled, engine.state == .running {
            engine.tick()
            if engine.state == .finished {
                completeSession()
                break
            }
            if let snapshot = engine.snapshot, snapshot.phase != lastHapticPhase {
                lastHapticPhase = snapshot.phase
                if settings.hapticsEnabled {
                    haptics.play(snapshot.phase, duration: snapshot.phaseRemaining)
                }
                // No-op unless bundled breath recordings are active. The
                // duration caps the bell at the phase plus the following
                // hold; the ring is ducked to a soft level during holds.
                audio.playBreathPhase(
                    snapshot.phase,
                    duration: snapshot.phaseRemaining + followingHoldDuration(after: snapshot.phase)
                )
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Hold length right after `phase`; zero when no hold follows.
    private func followingHoldDuration(after phase: BreathPhase) -> TimeInterval {
        switch phase {
        case .inhale: activeProtocol.holdAfterInhale
        case .exhale: activeProtocol.holdAfterExhale
        case .holdAfterInhale, .holdAfterExhale: 0
        }
    }
}
