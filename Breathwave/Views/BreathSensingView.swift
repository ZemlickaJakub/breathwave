import SwiftUI
import UIKit

/// Breath sensing: the phone lies flat on the belly and its motion is the
/// input — the wave shows the real breath, not a preset animation.
struct BreathSensingView: View {
    @State private var engine = BreathingEngine()
    @State private var sensor = BreathMotionSensor()
    @State private var hasRecorded = false
    @State private var finalSteadiness: Double?
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings
    @Environment(HealthService.self) private var healthService
    @Environment(\.dismiss) private var dismiss

    /// Sessions shorter than this are treated as accidental and not recorded.
    private static let minimumRecordedDuration: TimeInterval = 30

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            if engine.state == .running || engine.state == .paused {
                SensedWaveView(reading: sensor.reading, elapsed: engine.elapsed)
            } else {
                instructions
            }
            Spacer()
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
        .navigationTitle("Breath Sensor")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { teardown() }
    }

    private var instructions: some View {
        VStack(spacing: 16) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.tint)
            Text("Lie down and rest your iPhone flat on your belly.")
                .font(.title3)
                .multilineTextAlignment(.center)
            Text("Breathe naturally — the wave follows your real breath, measured by motion.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if engine.state == .finished, let finalSteadiness {
                Text("Steadiness: \(Int(finalSteadiness * 100)) %")
                    .font(.headline)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Session lifecycle

    private func startSession() {
        hasRecorded = false
        finalSteadiness = nil
        engine.start(.breathSensing, duration: nil)
        sensor.start()
        // No audio session keeps the app alive here; the screen must stay on.
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func pauseSession() {
        engine.pause()
        sensor.stop()
    }

    private func resumeSession() {
        engine.resume()
        sensor.start()
    }

    private func endSession() {
        finalSteadiness = sensor.reading?.steadiness
        engine.finish()
        completeSession()
    }

    private func completeSession() {
        guard !hasRecorded else { return }
        hasRecorded = true
        sensor.stop()
        UIApplication.shared.isIdleTimerDisabled = false
        guard engine.elapsed >= Self.minimumRecordedDuration else { return }
        let session = Session(
            completedAt: .now,
            duration: engine.elapsed,
            kind: .breathSensing,
            steadiness: finalSteadiness
        )
        sessionStore.add(session)
        if settings.healthSyncEnabled {
            let healthService = self.healthService
            Task { await healthService.save(session) }
        }
    }

    private func teardown() {
        UIApplication.shared.isIdleTimerDisabled = false
        sensor.stop()
        engine.reset()
    }
}

#Preview {
    NavigationStack {
        BreathSensingView()
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sensing.json")))
    .environment(AppSettings())
    .environment(HealthService())
}
