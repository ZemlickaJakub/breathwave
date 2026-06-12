import SwiftUI

/// Start / Pause / Resume / End controls shared by the session screens.
struct SessionControls: View {
    let state: BreathingEngine.State
    let onStart: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onEnd: () -> Void

    var body: some View {
        switch state {
        case .idle:
            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .finished:
            VStack(spacing: 12) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Button("Start", action: onStart)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        case .running:
            HStack(spacing: 16) {
                Button("Pause", action: onPause)
                    .buttonStyle(.bordered)
                Button("End", action: onEnd)
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        case .paused:
            HStack(spacing: 16) {
                Button("Resume", action: onResume)
                    .buttonStyle(.borderedProminent)
                Button("End", action: onEnd)
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }
}
