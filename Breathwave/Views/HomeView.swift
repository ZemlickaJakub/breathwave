import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings
    /// One greeting per launch — HomeView is the root view, so the initial
    /// State value is computed exactly once per app run.
    @State private var greeting = Greetings.pickForLaunch()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    SectionHeader("Breathing")
                    VStack(spacing: 12) {
                        ForEach(BreathingProtocol.presets) { breathingProtocol in
                            NavigationLink(value: breathingProtocol) {
                                ProtocolCard(breathingProtocol: breathingProtocol)
                            }
                            .buttonStyle(.plain)
                        }
                        NavigationLink {
                            CustomRhythmView()
                        } label: {
                            MenuCard(titleKey: "Custom Rhythm", icon: "slider.horizontal.3")
                        }
                        .buttonStyle(.plain)
                    }
                    SectionHeader("Meditation")
                    VStack(spacing: 12) {
                        NavigationLink {
                            MeditationTimerView()
                        } label: {
                            MenuCard(titleKey: "Meditation Timer", icon: "timer")
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: BreathingProtocol.om) {
                            MenuCard(titleKey: "Om Chanting", icon: "waveform")
                        }
                        .buttonStyle(.plain)
                    }
                    SectionHeader("Focus")
                    VStack(spacing: 12) {
                        NavigationLink {
                            FocusView()
                        } label: {
                            MenuCard(titleKey: "Mindful Pause", icon: "hand.raised")
                        }
                        .buttonStyle(.plain)
                    }
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("About", systemImage: "info.circle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .calmBackground()
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
                        GardenView()
                    } label: {
                        Label("Garden", systemImage: "camera.macro")
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "Breathwave")
                .font(.system(size: 36, weight: .semibold, design: .serif))
            Text(LocalizedStringKey(greeting))
                .font(.system(.subheadline, design: .serif).italic())
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            let streak = sessionStore.currentStreak()
            if streak > 0 {
                Text("Streak: \(streak) days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private var showsOnboarding: Binding<Bool> {
        Binding(
            get: { !settings.hasCompletedOnboarding },
            set: { if !$0 { settings.hasCompletedOnboarding = true } }
        )
    }
}

#Preview {
    HomeView()
        .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
        .environment(AppSettings())
        .environment(HealthService())
}
