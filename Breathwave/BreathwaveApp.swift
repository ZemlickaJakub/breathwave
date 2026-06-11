import SwiftUI

@main
struct BreathwaveApp: App {
    @State private var sessionStore = SessionStore()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(sessionStore)
        }
    }
}
