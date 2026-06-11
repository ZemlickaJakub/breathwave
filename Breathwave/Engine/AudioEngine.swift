import AVFoundation

/// Synthesized breathing tones, gongs and ambient playback.
/// The AVAudioSession must be active only while a session runs and deactivated
/// in teardown (App Review guideline 2.5.4 — background audio abuse).
/// TODO(Fáze 1): tone synthesis via AVAudioEngine (sine + envelope),
/// background playback with the screen off, gong samples.
@MainActor
final class AudioEngine {
    func beginSession() {
        // TODO(Fáze 1): configure AVAudioSession (.playback) and start the engine.
    }

    func endSession() {
        // TODO(Fáze 1): stop the engine and deactivate AVAudioSession.
    }
}
