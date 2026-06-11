import Foundation
import Testing
@testable import Breathwave

@MainActor
struct CustomRhythmStoreTests {
    private func makeStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "breathwave-rhythms-\(UUID().uuidString).json")
    }

    private var sampleRhythm: BreathingProtocol {
        BreathingProtocol(
            id: "custom", nameKey: "Custom Rhythm",
            inhale: 5, holdAfterInhale: 2, exhale: 7, holdAfterExhale: 1
        )
    }

    @Test func presetsPersistAcrossReload() {
        let url = makeStoreURL()
        let store = CustomRhythmStore(fileURL: url)
        store.addPreset(sampleRhythm, named: "Ranní")

        let reloaded = CustomRhythmStore(fileURL: url)
        #expect(reloaded.presets.count == 1)
        #expect(reloaded.presets.first?.nameKey == "Ranní")
        #expect(reloaded.presets.first?.inhale == 5)
        #expect(reloaded.presets.first?.exhale == 7)
    }

    @Test func presetIDsAreUnique() {
        let store = CustomRhythmStore(fileURL: makeStoreURL())
        store.addPreset(sampleRhythm, named: "A")
        store.addPreset(sampleRhythm, named: "B")
        #expect(Set(store.presets.map(\.id)).count == 2)
    }

    @Test func emptyAndWhitespaceNamesAreRejected() {
        let store = CustomRhythmStore(fileURL: makeStoreURL())
        store.addPreset(sampleRhythm, named: "")
        store.addPreset(sampleRhythm, named: "   ")
        #expect(store.presets.isEmpty)
    }

    @Test func nameIsTrimmed() {
        let store = CustomRhythmStore(fileURL: makeStoreURL())
        store.addPreset(sampleRhythm, named: "  Večerní  ")
        #expect(store.presets.first?.nameKey == "Večerní")
    }

    @Test func deleteRemovesPreset() {
        let url = makeStoreURL()
        let store = CustomRhythmStore(fileURL: url)
        store.addPreset(sampleRhythm, named: "A")
        store.addPreset(sampleRhythm, named: "B")
        store.deletePresets(at: IndexSet(integer: 0))
        #expect(store.presets.map(\.nameKey) == ["B"])

        let reloaded = CustomRhythmStore(fileURL: url)
        #expect(reloaded.presets.map(\.nameKey) == ["B"])
    }

    @Test func currentConfigurationPersists() {
        let url = makeStoreURL()
        let store = CustomRhythmStore(fileURL: url)
        store.saveCurrent(sampleRhythm)

        let reloaded = CustomRhythmStore(fileURL: url)
        #expect(reloaded.current == sampleRhythm)
    }

    @Test func freshStoreIsEmpty() {
        let store = CustomRhythmStore(fileURL: makeStoreURL())
        #expect(store.presets.isEmpty)
        #expect(store.current == nil)
    }
}
