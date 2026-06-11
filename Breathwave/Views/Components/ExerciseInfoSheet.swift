import SwiftUI

/// Discreet "what is this good for" sheet — opened from the info button,
/// stays out of the way otherwise.
struct ExerciseInfoSheet: View {
    let title: String
    let descriptionKey: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(LocalizedStringKey(descriptionKey))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
