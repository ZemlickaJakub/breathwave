import SwiftUI

struct BreathingSessionView: View {
    let breathingProtocol: BreathingProtocol

    @State private var engine = BreathingEngine()
    @State private var audio = AudioEngine()
    @State private var haptics = HapticsEngine()
    @State private var lastHapticPhase: BreathPhase?
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    /// Sessions shorter than this are treated as accidental and not recorded.
    private static let minimumRecordedDuration: TimeInterval = 30

    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            TimelineView(.animation) { context in
                VStack(spacing: 24) {
                    PacerView(
                        snapshot: engine.snapshot,
                        time: context.date.timeIntervalSinceReferenceDate
                    )
                    Text(elapsedText)
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            controls
        }
        .padding()
        .navigationTitle(breathingProtocol.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: engine.state) { await runPhaseLoop() }
        .onDisappear { teardown() }
    }

    private var elapsedText: String {
        Duration.seconds(engine.elapsed).formatted(.time(pattern: .minuteSecond))
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.state {
        case .idle, .finished:
            Button("Start") { startSession() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .running:
            HStack(spacing: 16) {
                Button("Pause") { pauseSession() }
                    .buttonStyle(.bordered)
                Button("End") { endSession() }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        case .paused:
            HStack(spacing: 16) {
                Button("Resume") { resumeSession() }
                    .buttonStyle(.borderedProminent)
                Button("End") { endSession() }
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    // MARK: - Session lifecycle

    private func startSession() {
        lastHapticPhase = nil
        haptics.prepare()
        engine.start(breathingProtocol)
        audio.startBreathing(breathingProtocol)
    }

    private func pauseSession() {
        engine.pause()
        audio.pauseTones()
    }

    private func resumeSession() {
        engine.resume()
        audio.resumeTones(breathingProtocol, at: engine.elapsed)
    }

    private func endSession() {
        engine.finish()
        audio.finishSession()
        haptics.stop()
        if engine.elapsed >= Self.minimumRecordedDuration {
            sessionStore.add(
                Session(
                    completedAt: .now,
                    duration: engine.elapsed,
                    kind: .breathing(protocolID: breathingProtocol.id)
                )
            )
        }
        dismiss()
    }

    private func teardown() {
        // Leaving mid-session (swipe back): cut audio immediately.
        // After endSession the engine is .finished and the gong rings out on its own.
        if engine.state == .running || engine.state == .paused {
            audio.deactivate()
        }
        haptics.stop()
        engine.reset()
    }

    /// Polls the engine while running: advances auto-finish and fires
    /// one haptic pattern per phase transition.
    private func runPhaseLoop() async {
        guard engine.state == .running else { return }
        while !Task.isCancelled, engine.state == .running {
            engine.tick()
            if let snapshot = engine.snapshot, snapshot.phase != lastHapticPhase {
                lastHapticPhase = snapshot.phase
                haptics.play(snapshot.phase, duration: snapshot.phaseRemaining)
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

#Preview {
    NavigationStack {
        BreathingSessionView(breathingProtocol: .coherent)
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
}
