import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(HealthService.self) private var healthService

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Sound", isOn: $settings.soundEnabled)
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
            } header: {
                Text("Session")
            }
            Section {
                Toggle("Save to Apple Health", isOn: $settings.healthSyncEnabled)
                    .disabled(!healthService.isAvailable)
            } footer: {
                Text("Completed sessions are saved to Apple Health as Mindful Minutes. Breathwave never reads any Health data.")
            }
            Section {
                NavigationLink("About") { AboutView() }
            }
        }
        .navigationTitle("Settings")
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
