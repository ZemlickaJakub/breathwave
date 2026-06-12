import SwiftUI

/// Discreet "what is this good for" sheet — opened from the info button,
/// stays out of the way otherwise.
struct ExerciseInfoSheet: View {
    let title: String
    let descriptionKey: String
    let whenKey: String
    /// Phase rhythm like "4 · 7 · 8" (seconds); nil for the meditation timer.
    var rhythm: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let rhythm {
                        Text(verbatim: "\(rhythm) s")
                            .font(.subheadline.monospacedDigit())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.tint.opacity(0.15), in: Capsule())
                    }
                    section("What it does", icon: "sparkles", textKey: descriptionKey)
                    section("When to use it", icon: "clock", textKey: whenKey)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
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

    private func section(_ header: LocalizedStringKey, icon: String, textKey: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(header, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.tint)
            Text(LocalizedStringKey(textKey))
                .foregroundStyle(.secondary)
        }
    }
}
