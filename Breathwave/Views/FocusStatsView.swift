import SwiftUI

/// Shows how often the user resisted or opened guarded apps, plus the
/// bloom-themed badges they have earned for staying present.
struct FocusStatsView: View {
    @State private var events: [FocusEvent] = []

    private var stats: FocusStats { FocusStats(events: events) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No pauses yet",
                        systemImage: "hand.raised",
                        description: Text("When a guarded app asks you to pause, your choices show up here.")
                    )
                    .padding(.top, 80)
                } else {
                    summary
                    SectionHeader("Badges")
                    badges
                }
            }
            .padding(20)
        }
        .calmBackground()
        .navigationTitle("Your pauses")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { events = FocusEventLog.all() }
    }

    private var summary: some View {
        VStack(spacing: 12) {
            row("Resisted today", value: stats.todayResisted)
            Divider()
            row("Opened today", value: stats.todayOpened)
            Divider()
            row("Resist streak", value: stats.currentResistStreak)
            Divider()
            row("Resisted in total", value: stats.totalResisted)
        }
        .font(.headline)
        .fontDesign(.serif)
        .cardChrome()
    }

    private func row(_ label: LocalizedStringKey, value: Int) -> some View {
        LabeledContent(label) {
            Text("\(value)").foregroundStyle(.primary)
        }
    }

    private var badges: some View {
        let status = FocusBadges.status(from: events)
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 16)],
            spacing: 20
        ) {
            ForEach(status, id: \.badge.id) { item in
                VStack(spacing: 8) {
                    Image(systemName: item.badge.systemImage)
                        .font(.system(size: 30))
                        .foregroundStyle(item.isEarned ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    Text(LocalizedStringKey(item.badge.title))
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(item.isEarned ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .opacity(item.isEarned ? 1 : 0.45)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FocusStatsView()
    }
}
