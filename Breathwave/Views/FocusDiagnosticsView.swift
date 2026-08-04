import SwiftUI

/// Developer diagnostics for Mindful Pause: shows the shared trace written by
/// the app and its extensions around shield events. Temporary tooling while the
/// re-lock behavior is being debugged on device; content is intentionally
/// untranslated technical text.
struct FocusDiagnosticsView: View {
    @State private var log = FocusShared.readDebugLog()

    /// Second-channel markers from the shield-config extension (shared
    /// defaults). Rendered above the log so a "custom shield drew but count
    /// didn't move" situation is visible at a glance.
    private var configHeader: String {
        let defaults = FocusShared.defaults
        let count = defaults.integer(forKey: FocusShared.Keys.diagConfigInvokeCount)
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm:ss"
        func stamp(_ key: String) -> String {
            let value = defaults.double(forKey: key)
            return value > 0 ? formatter.string(from: Date(timeIntervalSince1970: value)) : "never"
        }
        return """
        Config ext: invoked \(count)x, last \(stamp(FocusShared.Keys.diagConfigLastInvoked)), \
        init \(stamp(FocusShared.Keys.diagConfigInitAt))
        —
        """
    }

    var body: some View {
        ScrollView {
            Text(verbatim: configHeader + "\n" + (log.isEmpty ? "No events logged yet." : log))
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
                    UIPasteboard.general.string = configHeader + "\n" + log
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
