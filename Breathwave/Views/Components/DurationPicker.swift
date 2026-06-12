import SwiftUI

/// Segmented session-length picker; nil means open-ended.
struct DurationPicker: View {
    @Binding var minutes: Int?
    let choices: [Int?]

    var body: some View {
        Picker("Length", selection: $minutes) {
            ForEach(choices, id: \.self) { choice in
                if let choice {
                    Text("\(choice) min").tag(choice as Int?)
                } else {
                    Text(verbatim: "∞").tag(nil as Int?)
                }
            }
        }
        .pickerStyle(.segmented)
    }
}
