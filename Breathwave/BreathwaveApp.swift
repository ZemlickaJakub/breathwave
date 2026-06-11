import SwiftUI

@main
struct BreathwaveApp: App {
    @State private var sessionStore = SessionStore()
    @State private var settings = AppSettings()
    @State private var healthService = HealthService()
    @State private var customRhythms = CustomRhythmStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(sessionStore)
                .environment(settings)
                .environment(healthService)
                .environment(customRhythms)
        }
    }
}
