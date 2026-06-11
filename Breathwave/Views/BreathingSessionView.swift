import SwiftUI

struct BreathingSessionView: View {
    let breathingProtocol: BreathingProtocol

    @State private var engine = BreathingEngine()
    @Environment(SessionStore.self) private var sessionStore
    @Environment(\.dismiss) private var dismiss

    /// Sessions shorter than this are treated as accidental and not recorded.
    private static let minimumRecordedDuration: TimeInterval = 30

    var body: some View {
        VStack(spacing: 48) {
            Spacer()
            TimelineView(.animation) { _ in
                PacerView(snapshot: engine.snapshot)
            }
            Spacer()
            controls
        }
        .padding()
        .navigationTitle(breathingProtocol.localizedName)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { engine.reset() }
    }

    @ViewBuilder
    private var controls: some View {
        switch engine.state {
        case .idle, .finished:
            Button("Start") { engine.start(breathingProtocol) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        case .running:
            HStack(spacing: 16) {
                Button("Pause") { engine.pause() }
                    .buttonStyle(.bordered)
                Button("End") { endSession() }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
        case .paused:
            HStack(spacing: 16) {
                Button("Resume") { engine.resume() }
                    .buttonStyle(.borderedProminent)
                Button("End") { endSession() }
                    .buttonStyle(.bordered)
            }
            .controlSize(.large)
        }
    }

    private func endSession() {
        engine.finish()
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
}

#Preview {
    NavigationStack {
        BreathingSessionView(breathingProtocol: .coherent)
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
}
