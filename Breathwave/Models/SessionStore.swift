import Foundation
import Observation

/// Single source of truth for completed sessions. Persists as JSON in Documents.
@MainActor
@Observable
final class SessionStore {
    private(set) var sessions: [Session] = []

    @ObservationIgnored private let fileURL: URL
    @ObservationIgnored private let calendar: Calendar

    init(
        fileURL: URL = URL.documentsDirectory.appending(path: "sessions.json"),
        calendar: Calendar = .current
    ) {
        self.fileURL = fileURL
        self.calendar = calendar
        load()
    }

    func add(_ session: Session) {
        sessions.append(session)
        save()
    }

    // MARK: - Stats

    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    /// Consecutive days with at least one session, counting back from `reference`.
    /// A streak survives until the end of the current day: if today has no session
    /// yet but yesterday does, it counts from yesterday.
    func currentStreak(asOf reference: Date = .now) -> Int {
        let practiceDays = Set(sessions.map { calendar.startOfDay(for: $0.completedAt) })
        var day = calendar.startOfDay(for: reference)
        if !practiceDays.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  practiceDays.contains(yesterday)
            else { return 0 }
            day = yesterday
        }
        var streak = 0
        while practiceDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Practiced minutes per day for the last `count` days, oldest first.
    /// Days without sessions are included with 0 minutes (for the bar chart).
    func dailyMinutes(lastDays count: Int, asOf reference: Date = .now) -> [DailyMinutes] {
        let today = calendar.startOfDay(for: reference)
        return (0..<count).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let seconds = sessions
                .filter { calendar.startOfDay(for: $0.completedAt) == day }
                .reduce(0) { $0 + $1.duration }
            return DailyMinutes(day: day, minutes: seconds / 60)
        }
    }

    struct DailyMinutes: Identifiable, Equatable {
        let day: Date
        let minutes: Double
        var id: Date { day }
    }

    // MARK: - Persistence

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            sessions = try Self.decoder.decode([Session].self, from: data)
        } catch {
            // Corrupt store: start fresh rather than crash; session history is low-stakes data.
            sessions = []
        }
    }

    private func save() {
        do {
            let data = try Self.encoder.encode(sessions)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save sessions: \(error)")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
