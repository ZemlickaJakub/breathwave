import SwiftUI

/// Pre-session choices shown while idle: om length, duration,
/// and the in-the-dark toggle.
struct SessionSetupPickers: View {
    let isOmTraining: Bool
    @Binding var omExhaleSeconds: Int
    @Binding var selectedMinutes: Int?
    @Binding var inTheDark: Bool

    private static let durationChoices: [Int?] = [1, 3, 5, 10, 15, nil]
    private static let omExhaleChoices = [8, 10, 12, 15, 20]

    var body: some View {
        VStack(spacing: 12) {
            if isOmTraining {
                HStack {
                    Text("Om length")
                    Spacer()
                    Picker("Om length", selection: $omExhaleSeconds) {
                        ForEach(Self.omExhaleChoices, id: \.self) { Text("\($0) s").tag($0) }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 8)
            }
            DurationPicker(minutes: $selectedMinutes, choices: Self.durationChoices)
            Toggle(isOn: $inTheDark) {
                Label("In the dark", systemImage: "moon")
            }
            .padding(.horizontal, 8)
            if inTheDark {
                Text("The screen dims to black. Sound and gentle vibrations guide your breath.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            }
        }
    }
}
