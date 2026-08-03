import SwiftUI

/// Developer diagnostics for Mindful Pause: shows the shared trace written by
/// the app and its extensions around shield events. Temporary tooling while the
/// re-lock behavior is being debugged on device; content is intentionally
/// untranslated technical text.
struct FocusDiagnosticsView: View {
    @State private var log = FocusShared.readDebugLog()

    var body: some View {
        ScrollView {
            Text(verbatim: log.isEmpty ? "No events logged yet." : log)
                .font(.system(size: 11, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    UIPasteboard.general.string = log
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    FocusShared.clearDebugLog()
                    log = FocusShared.readDebugLog()
                } label: {
                    Label("Clear", systemImage: "trash")
                }
            }
        }
        .refreshable { log = FocusShared.readDebugLog() }
        .onAppear { log = FocusShared.readDebugLog() }
    }
}

#Preview {
    NavigationStack {
        FocusDiagnosticsView()
    }
}
