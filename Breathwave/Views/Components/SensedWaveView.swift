import SwiftUI

/// Live picture of the measured breath: unlike the pacer, the water level
/// here is not an animation — it is the sensed breath itself.
struct SensedWaveView: View {
    let reading: MotionBreathDetector.Reading?
    let elapsed: TimeInterval

    private static let emptyLevel = 0.08
    private static let fullLevel = 0.95

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                WaveShape(level: level, phase: elapsed * 1.4, amplitude: 0.05)
                    .fill(.tint.opacity(0.3))
                WaveShape(level: level, phase: elapsed * 1.0 + .pi / 1.5, amplitude: 0.035)
                    .fill(.tint.opacity(0.45))
            }
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.tint.opacity(0.5), lineWidth: 2))
            .frame(width: 240, height: 240)
            VStack(spacing: 6) {
                Text(statusLabel)
                    .font(.title2)
                if let bpm = reading?.breathsPerMinute {
                    Text("\(Int(bpm.rounded())) breaths/min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var level: Double {
        guard let reading, reading.hasSignal else { return Self.emptyLevel }
        return Self.emptyLevel + (Self.fullLevel - Self.emptyLevel) * reading.level
    }

    private var statusLabel: LocalizedStringKey {
        guard let reading, reading.hasSignal else { return "Finding your breath…" }
        return reading.isRising ? "Breathe In" : "Breathe Out"
    }
}
