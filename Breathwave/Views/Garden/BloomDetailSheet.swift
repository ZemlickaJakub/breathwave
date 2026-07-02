import SwiftUI

/// Full-size look at one bloom and the session that grew it.
struct BloomDetailSheet: View {
    let session: Session

    var body: some View {
        VStack(spacing: 24) {
            BreathBloomView(parameters: .from(session))
                .frame(width: 260, height: 260)
            VStack(spacing: 6) {
                Text(session.completedAt, format: .dateTime.day().month(.wide).year())
                    .font(.headline)
                    .fontDesign(.serif)
                Text(durationText)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .calmBackground()
        .presentationDetents([.medium])
    }

    private var durationText: String {
        Duration.seconds(session.duration)
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated))
    }
}

#Preview {
    BloomDetailSheet(session: Session(
        completedAt: .now,
        duration: 480,
        kind: .breathing(protocolID: "coherent")
    ))
}
