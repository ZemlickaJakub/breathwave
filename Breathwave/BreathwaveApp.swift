import SwiftUI

@main
struct BreathwaveApp: App {
    @State private var sessionStore = SessionStore()
    @State private var settings = AppSettings()
    @State private var healthService = HealthService()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(sessionStore)
                .environment(settings)
                .environment(healthService)
        }
    }
}
