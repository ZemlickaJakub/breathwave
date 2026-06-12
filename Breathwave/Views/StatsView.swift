import Charts
import SwiftUI

struct StatsView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if sessionStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "No sessions yet",
                        systemImage: "water.waves",
                        description: Text("Finish your first breathing session and your progress will show up here.")
                    )
                    .padding(.top, 80)
                } else {
                    summaryCard
                    SectionHeader("Last 7 days")
                    weeklyChart
                        .cardChrome()
                }
            }
            .padding(20)
        }
        .calmBackground()
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        VStack(spacing: 12) {
            LabeledContent("Current streak") {
                Text("\(sessionStore.currentStreak()) days")
                    .foregroundStyle(.primary)
            }
            .font(.headline)
            .fontDesign(.serif)
            Divider()
            LabeledContent("Total time") {
                Text(totalTimeText)
                    .foregroundStyle(.primary)
            }
            .font(.headline)
            .fontDesign(.serif)
        }
        .cardChrome()
    }

    private var totalTimeText: String {
        Duration.seconds(sessionStore.totalDuration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var weeklyChart: some View {
        let daily = sessionStore.dailyMinutes(lastDays: 7)
        let maxMinutes = daily.map(\.minutes).max() ?? 0
        return Chart(daily) { item in
            BarMark(
                x: .value("Day", item.day, unit: .day),
                y: .value("Minutes", item.minutes)
            )
            .foregroundStyle(.tint)
            .cornerRadius(3)
            .annotation(position: .top, spacing: 4) {
                if let label = Self.durationLabel(minutes: item.minutes) {
                    Text(label)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        // Numbers live on the bars; a fractional-minutes axis only confuses.
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...max(5, maxMinutes * 1.3))
        .frame(height: 180)
        .padding(.vertical, 8)
    }

    /// "36 s" below a minute, then "5 min" / "1 h 5 min"; nothing for empty days.
    private static func durationLabel(minutes: Double) -> String? {
        guard minutes > 0 else { return nil }
        let duration = Duration.seconds(minutes * 60)
        if minutes < 1 {
            return duration.formatted(.units(allowed: [.seconds], width: .narrow))
        }
        return duration.formatted(.units(allowed: [.hours, .minutes], width: .narrow))
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
}
