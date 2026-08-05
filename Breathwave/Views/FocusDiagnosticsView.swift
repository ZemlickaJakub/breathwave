import SwiftUI
import DeviceActivity
import FamilyControls

/// Developer diagnostics for Mindful Pause: shows the shared trace written by
/// the app and its extensions around shield events. Temporary tooling while the
/// re-lock behavior is being debugged on device; content is intentionally
/// untranslated technical text.
struct FocusDiagnosticsView: View {
    @State private var log = FocusShared.readDebugLog()
    @State private var testArmed = false
    @State private var thresholdTestArmed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Dev-only experiment (verbatim on purpose): arms a shield
                // application ~30 s from now via a schedule REGISTERED BY THE
                // MAIN APP — discriminates whether the scheduler's identity
                // decides custom vs. generic rendering on a mid-use apply.
                Button {
                    armTestLock()
                    testArmed = true
                } label: {
                    Text(verbatim: testArmed ? "Test armed — open FB/IG now" : "Test: lock in 30 s (from app)")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)

                // Same discriminator, other callback: arms an app-armed
                // 1-minute USAGE THRESHOLD (eventDidReachThreshold) instead of
                // an interval start — build 22 saw interval-start locks render
                // custom while threshold locks sometimes went generic.
                Button {
                    armThresholdTestLock()
                    thresholdTestArmed = true
                } label: {
                    Text(verbatim: thresholdTestArmed
                        ? "Threshold test armed — use FB/IG ~1 min"
                        : "Test: lock after 1 min of use (threshold)")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)

                Text(verbatim: log.isEmpty ? "No events logged yet." : log)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
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

    /// Arms the monitor to apply the shield ~30 s from now. Crucially, this
    /// `startMonitoring` call is made by the MAIN APP process, unlike the
    /// grace re-lock (armed by the shield-action extension) — the on-device
    /// report in kingstinct#82 saw the custom shield render mid-use only for
    /// app-armed schedules.
    private func armTestLock() {
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let start = Date().addingTimeInterval(30)
        let end = start.addingTimeInterval(16 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        let name = DeviceActivityName(FocusShared.testActivityName)
        center.stopMonitoring([name])
        try? center.startMonitoring(name, during: schedule)
        FocusShared.debugLog("app", "armed test lock +30 s (main-app scheduler)")
    }

    /// Arms a 1-minute usage-threshold event on a schedule the monitor's
    /// interval callbacks ignore, so ONLY `eventDidReachThreshold` can re-lock.
    /// With the guarded selection as the event's target: open a guarded app,
    /// use it for a minute, and watch which shield the re-lock draws.
    private func armThresholdTestLock() {
        guard let data = FocusShared.defaults.data(forKey: FocusShared.Keys.selection),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            FocusShared.debugLog("app", "threshold test NOT armed — no selection")
            return
        }
        let center = DeviceActivityCenter()
        let calendar = Calendar.current
        let start = Date().addingTimeInterval(5)
        let end = start.addingTimeInterval(16 * 60)
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute, .second], from: start),
            intervalEnd: calendar.dateComponents([.hour, .minute, .second], from: end),
            repeats: false
        )
        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: 1),
                includesPastActivity: false
            )
        } else {
            event = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: 1)
            )
        }
        let name = DeviceActivityName(FocusShared.testUsageActivityName)
        center.stopMonitoring([name])
        try? center.startMonitoring(
            name,
            during: schedule,
            events: [.init(FocusShared.openEventPrefix + "test"): event]
        )
        FocusShared.debugLog("app", "armed threshold test — lock after 1 min of use")
    }
}

#Preview {
    NavigationStack {
        FocusDiagnosticsView()
    }
}
