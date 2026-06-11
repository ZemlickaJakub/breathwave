import SwiftUI

struct AboutView: View {
    @State private var showsWebsite = false

    private let websiteURL = URL(string: "https://jakubzemlicka.cz")

    var body: some View {
        List {
            Section {
                Text("Breathwave was vibecoded: Jakub built it with his AI agent — no team of developers, no investor. It is free, has no ads and collects no data.")
                if websiteURL != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Interested in an app or an AI assistant like this for your business? Get in touch via jakubzemlicka.cz.")
                            .foregroundStyle(.secondary)
                        Button("Open jakubzemlicka.cz") {
                            showsWebsite = true
                        }
                    }
                }
            } header: {
                Text("The story")
            }
            TipJarView()
        }
        .navigationTitle("About")
        .sheet(isPresented: $showsWebsite) {
            if let websiteURL {
                SafariView(url: websiteURL)
                    .ignoresSafeArea()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
