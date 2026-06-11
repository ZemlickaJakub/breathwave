import HealthKit

/// Write-only sync of completed sessions to Apple Health as Mindful Minutes.
/// Opt-in via Settings; the app never reads any Health data.
/// TODO(Fáze 2): request write authorization for HKCategoryType .mindfulSession
/// and save a sample per completed session.
@MainActor
final class HealthService {
    func save(_ session: Session) async {
        // TODO(Fáze 2)
    }
}
