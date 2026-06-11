import Charts
import SwiftUI

struct StatsView: View {
    @Environment(SessionStore.self) private var sessionStore

    var body: some View {
        List {
            if sessionStore.sessions.isEmpty {
                ContentUnavailableView(
                    "No sessions yet",
                    systemImage: "water.waves",
                    description: Text("Finish your first breathing session and your progress will show up here.")
                )
            } else {
                Section {
                    LabeledContent("Current streak") {
                        Text("\(sessionStore.currentStreak()) days")
                    }
                    LabeledContent("Total time") {
                        Text(totalTimeText)
                    }
                }
                Section("Last 7 days") {
                    weeklyChart
                }
            }
        }
        .navigationTitle("Stats")
    }

    private var totalTimeText: String {
        Duration.seconds(sessionStore.totalDuration)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private var weeklyChart: some View {
        Chart(sessionStore.dailyMinutes(lastDays: 7)) { item in
            BarMark(
                x: .value("Day", item.day, unit: .day),
                y: .value("Minutes", item.minutes)
            )
            .foregroundStyle(.tint)
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .environment(SessionStore(fileURL: FileManager.default.temporaryDirectory.appending(path: "preview-sessions.json")))
}
