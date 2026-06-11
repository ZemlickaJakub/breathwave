import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings

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
                Section {
                    NavigationLink {
                        MeditationTimerView()
                    } label: {
                        Label("Meditation Timer", systemImage: "timer")
                    }
                    NavigationLink(value: BreathingProtocol.om) {
                        Label("Om Chanting", systemImage: "waveform")
                    }
                } header: {
                    Text("Meditation")
                }
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                }
            }
            .navigationTitle(Text(verbatim: "Breathwave"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        StatsView()
                    } label: {
                        Label("Stats", systemImage: "chart.bar")
                    }
                }
            }
            .navigationDestination(for: BreathingProtocol.self) { breathingProtocol in
                BreathingSessionView(breathingProtocol: breathingProtocol)
            }
        }
        .fullScreenCover(isPresented: showsOnboarding) {
            OnboardingView { settings.hasCompletedOnboarding = true }
        }
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )
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
        .environment(AppSettings())
        .environment(HealthService())
}
