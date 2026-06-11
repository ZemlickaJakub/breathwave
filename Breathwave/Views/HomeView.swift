import SwiftUI

struct HomeView: View {
    @Environment(SessionStore.self) private var sessionStore
    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    sectionHeader("Breathing")
                    VStack(spacing: 12) {
                        ForEach(BreathingProtocol.presets) { breathingProtocol in
                            NavigationLink(value: breathingProtocol) {
                                ProtocolCard(breathingProtocol: breathingProtocol)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    sectionHeader("Meditation")
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
            let streak = sessionStore.currentStreak()
            if streak > 0 {
                Text("Streak: \(streak) days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(1.2)
            .foregroundStyle(.secondary)
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
