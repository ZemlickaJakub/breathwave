import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HealthService.self) private var healthService

    var body: some View {
        @Bindable var settings = settings
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Session")
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                        .font(.headline)
                        .fontDesign(.serif)
                        .tint(.accentColor)
                        .cardChrome()
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Sounds")
                    VStack(spacing: 12) {
                        HStack {
                            Text("Breathing sound")
                                .font(.headline)
                                .fontDesign(.serif)
                            Spacer()
                            Picker("Breathing sound", selection: $settings.breathSound) {
                                ForEach(BreathSound.allCases) { sound in
                                    Text(LocalizedStringKey(sound.nameKey)).tag(sound)
                                }
                            }
                            .labelsHidden()
                        }
                        Divider()
                        HStack {
                            Text("Gong")
                                .font(.headline)
                                .fontDesign(.serif)
                            Spacer()
                            Picker("Gong", selection: $settings.gongSound) {
                                ForEach(GongSound.allCases) { sound in
                                    Text(LocalizedStringKey(sound.nameKey)).tag(sound)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                    .cardChrome()
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Health")
                    Toggle("Save to Apple Health", isOn: $settings.healthSyncEnabled)
                        .font(.headline)
                        .fontDesign(.serif)
                        .tint(.accentColor)
                        .disabled(!healthService.isAvailable)
                        .cardChrome()
                    Text("Completed sessions are saved to Apple Health as Mindful Minutes. Breathwave never reads any Health data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                NavigationLink {
                    AboutView()
                } label: {
                    MenuCard(titleKey: "About", icon: "info.circle")
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .calmBackground()
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.healthSyncEnabled) { _, enabled in
            guard enabled else { return }
            Task {
                let granted = await healthService.requestAuthorization()
                if !granted {
                    settings.healthSyncEnabled = false
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppSettings())
    .environment(HealthService())
}
