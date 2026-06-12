import Foundation
import Observation

/// User-defined breathing rhythms: the last edited configuration plus
/// named presets. Persists as JSON in Documents.
@MainActor
@Observable
final class CustomRhythmStore {
    private struct Payload: Codable {
        var current: BreathingProtocol?
        var presets: [BreathingProtocol]
    }

    private(set) var presets: [BreathingProtocol] = []
    private(set) var current: BreathingProtocol?

    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = URL.documentsDirectory.appending(path: "custom-rhythms.json")) {
        self.fileURL = fileURL
        load()
    }

    /// Remembers the editor's last configuration between visits.
    func saveCurrent(_ rhythm: BreathingProtocol) {
        current = rhythm
        save()
    }

    /// Saves the rhythm under a user-given name; empty names are ignored.
    func addPreset(_ rhythm: BreathingProtocol, named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let preset = BreathingProtocol(
            id: "custom-\(UUID().uuidString)",
            nameKey: trimmed,
            inhale: rhythm.inhale,
            holdAfterInhale: rhythm.holdAfterInhale,
            exhale: rhythm.exhale,
            holdAfterExhale: rhythm.holdAfterExhale
        )
        presets.append(preset)
        save()
    }

    func deletePresets(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return }
        presets = payload.presets
        current = payload.current
    }

    private func save() {
        let payload = Payload(current: current, presets: presets)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save custom rhythms: \(error)")
        }
    }
}
