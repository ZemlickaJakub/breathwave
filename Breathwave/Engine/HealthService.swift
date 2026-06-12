import HealthKit
import Observation

/// Write-only sync of completed sessions to Apple Health as Mindful Minutes.
/// Opt-in via Settings; the app never reads any Health data.
@MainActor
@Observable
final class HealthService {
    @ObservationIgnored private let store = HKHealthStore()

    private var mindfulType: HKCategoryType {
        HKCategoryType(.mindfulSession)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Asks for write permission. Returns false when Health is unavailable
    /// or the user denied sharing.
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [mindfulType], read: [])
        } catch {
            return false
        }
        return store.authorizationStatus(for: mindfulType) == .sharingAuthorized
    }

    func save(_ session: Session) async {
        guard isAvailable,
              store.authorizationStatus(for: mindfulType) == .sharingAuthorized,
              session.duration > 0
        else { return }
        let sample = HKCategorySample(
            type: mindfulType,
            value: HKCategoryValue.notApplicable.rawValue,
            start: session.completedAt.addingTimeInterval(-session.duration),
            end: session.completedAt
        )
        try? await store.save(sample)
    }
}
