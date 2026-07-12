import Foundation
import Testing
@testable import Breathwave

struct ShieldButtonsTests {
    private func date(_ h: Int, _ m: Int = 0) -> Date {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c.date(from: DateComponents(year: 2026, month: 7, day: 12, hour: h, minute: m))!
    }

    // The whole point: the two extensions must agree, so the same inputs
    // must always yield the same button layout.
    @Test func sameInputsAgree() {
        let token = Data([1, 2, 3, 4])
        let moment = date(14, 30)
        #expect(
            ShieldButtons.openIsPrimary(tokenData: token, at: moment)
                == ShieldButtons.openIsPrimary(tokenData: token, at: moment)
        )
    }

    @Test func differentAppsCanDiffer() {
        // Across a spread of tokens the layout is not constant.
        let moment = date(14)
        let results = (0..<16).map {
            ShieldButtons.openIsPrimary(tokenData: Data([UInt8($0)]), at: moment)
        }
        #expect(Set(results).count == 2)
    }

    @Test func layoutFlipsAcrossHours() {
        let token = Data([42])
        let flips = (0..<24).map { ShieldButtons.openIsPrimary(tokenData: token, at: date($0)) }
        #expect(Set(flips).count == 2)
    }

    @Test func stableWithinTheSameHour() {
        let token = Data([7])
        #expect(
            ShieldButtons.openIsPrimary(tokenData: token, at: date(9, 0))
                == ShieldButtons.openIsPrimary(tokenData: token, at: date(9, 59))
        )
    }

    @Test func missingTokenStillDecides() {
        // A nil token must not crash and still returns a definite answer.
        _ = ShieldButtons.openIsPrimary(tokenData: nil, at: date(12))
    }
}
