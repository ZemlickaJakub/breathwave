import CoreMotion
import Foundation
import Observation

/// Feeds device-motion samples into the breath detector while a sensing
/// session runs. Raw device motion needs no permission prompt and no
/// entitlement — nothing ever leaves the device.
@MainActor
@Observable
final class BreathMotionSensor {
    private(set) var reading: MotionBreathDetector.Reading?

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var detector = MotionBreathDetector()
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    var isAvailable: Bool {
        manager.isDeviceMotionAvailable
    }

    func start() {
        guard isAvailable, pollTask == nil else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates()
        // Poll on the main actor, same style as the session phase loop.
        // The detector ignores repeated timestamps between fresh samples.
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                if let self, let motion = self.manager.deviceMotion {
                    self.reading = self.detector.process(value: motion.gravity.z, at: motion.timestamp)
                }
                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        manager.stopDeviceMotionUpdates()
        reading = nil
        detector = MotionBreathDetector()
    }
}
