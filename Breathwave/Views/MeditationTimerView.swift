import SwiftUI

struct MeditationTimerView: View {
    @State private var engine = BreathingEngine()
    @State private var audio = AudioEngine()
    @State private var selectedMinutes = 10
    @State private var bellMinutes = 0
    @State private var ambientEnabled = true
    @State private var bellsPlayed = 0
    @State private var hasRecorded = false
    @State private var showsInfo = false
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings
    @Environment(HealthService.self) private var healthService
    @Environment(\.dismiss) private var dismiss

    private static let minimumRecordedDuration: TimeInterval = 30
    private static let durationChoices = [5, 10, 15, 20, 30, 45, 60]
    private static let bellChoices = [0, 5, 10]

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in
                VStack(spacing: 20) {
                    Text(remainingText)
                        .font(.system(size: 60, weight: .light).monospacedDigit())
                    ProgressView(value: min(1, progress))
                        .frame(width: 220)
                        .tint(.accentColor)
                }
            }
            Spacer()
            if engine.state == .idle || engine.state == .finished {
                options
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
        .navigationTitle("Meditation")
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
                title: String(localized: "Meditation"),
                descriptionKey: "meditation.description",
                whenKey: "meditation.when"
            )
        }
        .task(id: engine.state) { await runTimerLoop() }
        .onDisappear { teardown() }
    }

    private var remainingText: String {
        let seconds = engine.snapshot?.remaining ?? TimeInterval(selectedMinutes * 60)
        return Duration.seconds(seconds).formatted(.time(pattern: .minuteSecond))
    }

    private var progress: Double {
        guard let planned = engine.plannedDuration, planned > 0 else { return 0 }
        return engine.elapsed / planned
    }

    private var options: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Length")
                Spacer()
                Picker("Length", selection: $selectedMinutes) {
                    ForEach(Self.durationChoices, id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden()
            }
            HStack {
                Text("Interval bells")
                Spacer()
                Picker("Interval bells", selection: $bellMinutes) {
                    Text("Off").tag(0)
                    ForEach(Self.bellChoices.dropFirst(), id: \.self) { Text("\($0) min").tag($0) }
                }
                .labelsHidden()
            }
            Toggle("Ambient sound", isOn: $ambientEnabled)
                .disabled(!settings.soundEnabled)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Session lifecycle

    private func startSession() {
        hasRecorded = false
        bellsPlayed = 0
        engine.start(.meditation, duration: TimeInterval(selectedMinutes * 60))
        let wantsAmbient = settings.soundEnabled && ambientEnabled
        audio.startSession(
            program: wantsAmbient ? .ambient(timbre: settings.breathSound.timbre) : nil,
            gongSound: settings.gongSound
        )
        if settings.soundEnabled { audio.playGong() }
    }

    private func pauseSession() {
        engine.pause()
        audio.pauseProgram()
    }

    private func resumeSession() {
        engine.resume()
        let wantsAmbient = settings.soundEnabled && ambientEnabled
        audio.resumeProgram(
            wantsAmbient ? .ambient(timbre: settings.breathSound.timbre) : nil,
            at: engine.elapsed
        )
    }

    private func endSession() {
        engine.finish()
        completeSession()
        dismiss()
    }

    private func completeSession() {
        guard !hasRecorded else { return }
        hasRecorded = true
        if settings.soundEnabled {
            audio.finishSession()
        } else {
            audio.deactivate()
        }
        guard engine.elapsed >= Self.minimumRecordedDuration else { return }
        let session = Session(completedAt: .now, duration: engine.elapsed, kind: .meditation)
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
        engine.reset()
    }

    private func runTimerLoop() async {
        guard engine.state == .running else { return }
        while !Task.isCancelled, engine.state == .running {
            engine.tick()
            if engine.state == .finished {
                completeSession()
                break
            }
            playIntervalBellIfDue()
            try? await Task.sleep(for: .milliseconds(250))
        }
    }

    private func playIntervalBellIfDue() {
        guard bellMinutes > 0, settings.soundEnabled else { return }
        let interval = TimeInterval(bellMinutes * 60)
        let due = Int(engine.elapsed / interval)
        guard due > bellsPlayed else { return }
        bellsPlayed = due
        // Skip a bell that would collide with the closing gong.
        if let remaining = engine.snapshot?.remaining, remaining > 5 {
            audio.playGong(volume: 0.4)
        }
    }
}
