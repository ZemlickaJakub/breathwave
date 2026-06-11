import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BreathingProtocol.presets) { breathingProtocol in
                        NavigationLink(value: breathingProtocol) {
                            ProtocolRow(breathingProtocol: breathingProtocol)
                        }
                    }
                } header: {
                    Text("Breathing")
                } footer: {
                    let streak = sessionStore.currentStreak()
                    if streak > 0 {
                        Text("Streak: \(streak) days")
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Breathwave"))
            .navigationDestination(for: BreathingProtocol.self) { breathingProtocol in
                BreathingSessionView(breathingProtocol: breathingProtocol)
            }
        }
    }
}

private struct ProtocolRow: View {
    let breathingProtocol: BreathingProtocol

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(breathingProtocol.localizedName)
            Text(rhythmDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// Phase durations as e.g. "4 · 7 · 8" — language-neutral, no localization needed.
    private var rhythmDescription: String {
        breathingProtocol.phases
            .map { $0.duration.formatted(.number.precision(.fractionLength(0...1))) }
            .joined(separator: " · ")
    }
}

#Preview {
    HomeView()
        .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
}
