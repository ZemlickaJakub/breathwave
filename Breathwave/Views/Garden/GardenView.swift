import SwiftUI

/// The garden: every finished session grows one unique bloom,
/// rebuilt deterministically from the session store.
struct GardenView: View {
    @Environment(SessionStore.self) private var sessionStore
    @State private var selected: Session?

    private static let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        ScrollView {
            if sessionStore.sessions.isEmpty {
                ContentUnavailableView(
                    "No blooms yet",
                    systemImage: "camera.macro",
                    description: Text("Each finished session grows a unique bloom. Your garden starts with your next breath.")
                )
                .padding(.top, 80)
            } else {
                LazyVGrid(columns: Self.columns, spacing: 16) {
                    ForEach(sessionStore.sessions.reversed()) { session in
                        Button {
                            selected = session
                        } label: {
                            BreathBloomView(parameters: .from(session))
                                .frame(height: 96)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .calmBackground()
        .navigationTitle("Garden")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selected) { session in
            BloomDetailSheet(session: session)
        }
    }
}

#Preview {
    NavigationStack {
        GardenView()
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-garden.json")))
}
