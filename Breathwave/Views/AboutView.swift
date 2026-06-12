import SwiftUI

struct AboutView: View {
    @State private var showsWebsite = false
    @State private var showsIdeas = false

    private let websiteURL = URL(string: "https://jakubzemlicka.cz")
    private let ideasURL = URL(string: "https://github.com/ZemlickaJakub/breathwave/issues")

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        List {
            hero
            storySection
            promiseSection
            ideasSection
            contactSection
            TipJarView()
        }
        .scrollContentBackground(.hidden)
        .calmBackground()
        .navigationTitle("About")
        .sheet(isPresented: $showsWebsite) {
            if let websiteURL {
                SafariView(url: websiteURL)
                    .ignoresSafeArea()
            }
        }
    }

    private var hero: some View {
        Section {
            VStack(spacing: 10) {
                Image(systemName: "water.waves")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(.tint)
                    .frame(width: 84, height: 84)
                    .background(Circle().fill(.tint.opacity(0.12)))
                Text(verbatim: "Breathwave")
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                Text("Breathe. Be.")
                    .font(.system(.subheadline, design: .serif).italic())
                    .foregroundStyle(.secondary)
                Text(verbatim: "v\(version)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .listRowBackground(Color.clear)
    }

    private var storySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Breathwave was born from a simple wish: a quiet place to breathe, without ads, subscriptions or anything pulling at your attention.")
                Text("It was vibecoded — Jakub built it together with his AI agent. No team of developers, no investors, just curiosity and many calm breaths.")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        } header: {
            Text("The story")
        }
    }

    private var promiseSection: some View {
        Section {
            Label("Free forever", systemImage: "heart")
            Label("No ads, no subscriptions", systemImage: "hand.raised")
            Label("No tracking — everything stays on your device", systemImage: "lock")
        } header: {
            Text("The promise")
        }
    }

    @ViewBuilder private var ideasSection: some View {
        if ideasURL != nil {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Have an idea, or is something missing? Breathwave is built in the open — share your thoughts on GitHub.")
                        .foregroundStyle(.secondary)
                    Button("Share an idea") {
                        showsIdeas = true
                    }
                    .sheet(isPresented: $showsIdeas) {
                        if let ideasURL {
                            SafariView(url: ideasURL)
                                .ignoresSafeArea()
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Ideas and requests")
            }
        }
    }

    @ViewBuilder private var contactSection: some View {
        if websiteURL != nil {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Interested in an app or an AI assistant like this for your business?")
                        .foregroundStyle(.secondary)
                    Button("Open jakubzemlicka.cz") {
                        showsWebsite = true
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Get in touch")
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
