import SwiftUI

/// Three skippable intro screens shown on first launch.
struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var page = 0

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Skip") { onFinish() }
                    .padding()
            }
            TabView(selection: $page) {
                OnboardingPage(
                    icon: "water.waves",
                    title: "Breathe with the wave",
                    text: "Pick a protocol and follow the rising and falling water."
                )
                .tag(0)
                OnboardingPage(
                    icon: "moon.zzz.fill",
                    title: "Screen off, session on",
                    text: "The ocean keeps guiding you even with the screen off."
                )
                .tag(1)
                OnboardingPage(
                    icon: "lock.fill",
                    title: "Private by design",
                    text: "No accounts, no ads, no tracking. Everything stays on your phone."
                )
                .tag(2)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            Group {
                if page < 2 {
                    Button("Continue") { withAnimation { page += 1 } }
                } else {
                    Button("Get Started") { onFinish() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 32)
        }
    }
}

private struct OnboardingPage: View {
    let icon: String
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(text)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
}

#Preview {
    OnboardingView {}
}
