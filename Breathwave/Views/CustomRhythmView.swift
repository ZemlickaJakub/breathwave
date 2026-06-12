import SwiftUI

/// Editor for the fifth protocol: all four phases set by the user,
/// with named presets.
struct CustomRhythmView: View {
    @Environment(CustomRhythmStore.self) private var store
    @State private var inhale: Double = 4
    @State private var holdAfterInhale: Double = 0
    @State private var exhale: Double = 6
    @State private var holdAfterExhale: Double = 0
    @State private var showsSaveDialog = false
    @State private var presetName = ""
    @State private var hasLoadedCurrent = false

    private var rhythm: BreathingProtocol {
        BreathingProtocol(
            id: "custom",
            nameKey: "Custom Rhythm",
            inhale: inhale,
            holdAfterInhale: holdAfterInhale,
            exhale: exhale,
            holdAfterExhale: holdAfterExhale
        )
    }

    private var isValid: Bool {
        inhale > 0 && exhale > 0
    }

    var body: some View {
        List {
            Section {
                DurationRow("Breathe In", value: $inhale)
                DurationRow("Hold", value: $holdAfterInhale)
                DurationRow("Breathe Out", value: $exhale)
                DurationRow("Hold", value: $holdAfterExhale)
            } header: {
                Text("Rhythm")
            } footer: {
                Text(verbatim: "\(rhythm.rhythmSummary) s")
                    .monospacedDigit()
            }
            Section {
                NavigationLink(value: rhythm) {
                    Text("Start")
                        .fontWeight(.semibold)
                }
                .disabled(!isValid)
                Button("Save as preset") {
                    presetName = ""
                    showsSaveDialog = true
                }
                .disabled(!isValid)
            }
            if !store.presets.isEmpty {
                Section {
                    ForEach(store.presets) { preset in
                        Button {
                            load(preset)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.localizedName)
                                Text(verbatim: "\(preset.rhythmSummary) s")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tint(.primary)
                    }
                    .onDelete { store.deletePresets(at: $0) }
                } header: {
                    Text("Saved presets")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .calmBackground()
        .navigationTitle("Custom Rhythm")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Save as preset", isPresented: $showsSaveDialog) {
            TextField("Name", text: $presetName)
            Button("Save") { store.addPreset(rhythm, named: presetName) }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear { loadCurrentOnce() }
        .onDisappear { store.saveCurrent(rhythm) }
    }

    private func loadCurrentOnce() {
        guard !hasLoadedCurrent else { return }
        hasLoadedCurrent = true
        if let current = store.current {
            load(current)
        }
    }

    private func load(_ preset: BreathingProtocol) {
        inhale = preset.inhale
        holdAfterInhale = preset.holdAfterInhale
        exhale = preset.exhale
        holdAfterExhale = preset.holdAfterExhale
    }
}

private struct DurationRow: View {
    let label: LocalizedStringKey
    @Binding var value: Double

    init(_ label: LocalizedStringKey, value: Binding<Double>) {
        self.label = label
        self._value = value
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer()
            Text(verbatim: "\(value.formatted(.number.precision(.fractionLength(0...1)))) s")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper(label, value: $value, in: 0...15, step: 0.5)
                .labelsHidden()
        }
    }
}

#Preview {
    NavigationStack {
        CustomRhythmView()
    }
    .environment(CustomRhythmStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-rhythms.json")))
}
