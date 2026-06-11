import SwiftUI

struct AboutView: View {
    @State private var showsWebsite = false

    private let websiteURL = URL(string: "https://jakubzemlicka.cz")

    var body: some View {
        List {
            Section {
                Text("Breathwave was built in 14 days by Jakub and his AI agent — no team of developers. It is free, has no ads and collects no data.")
                if websiteURL != nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Want your own app or AI assistant?")
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
