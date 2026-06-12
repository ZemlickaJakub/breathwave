import XCTest

/// Walks the app and captures App Store screenshots as test attachments.
/// Run via the BreathwaveScreenshots scheme; extract with
/// `xcrun xcresulttool export attachments`.
final class ScreenshotTests: XCTestCase {
    private struct Strings {
        let coherent: String
        let meditationTimer: String
        let stats: String
        let settings: String
        let start: String
        let end: String

        static let en = Strings(
            coherent: "Coherent Breathing", meditationTimer: "Meditation Timer",
            stats: "Stats", settings: "Settings", start: "Start", end: "End"
        )
        static let cs = Strings(
            coherent: "Koherentní dech", meditationTimer: "Meditační timer",
            stats: "Statistiky", settings: "Nastavení", start: "Začít", end: "Ukončit"
        )
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshotsEnglish() throws {
        captureAll(language: "en", strings: .en)
    }

    func testScreenshotsCzech() throws {
        captureAll(language: "cs", strings: .cs)
    }

    private func captureAll(language: String, strings: Strings) {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(\(language))",
            "-onboarding.completed", "YES",
        ]
        app.launch()

        // 01 — Home with protocol cards.
        XCTAssertTrue(app.staticTexts[strings.coherent].waitForExistence(timeout: 5))
        snap("\(language)-01-home")

        // 02 — Pacer mid-inhale in a running session.
        app.staticTexts[strings.coherent].firstMatch.tap()
        XCTAssertTrue(app.buttons[strings.start].waitForExistence(timeout: 5))
        app.buttons[strings.start].tap()
        Thread.sleep(forTimeInterval: 3.6)
        snap("\(language)-02-breathe")
        app.buttons[strings.end].tap()

        // 03 — Stats with seeded history.
        XCTAssertTrue(app.buttons[strings.stats].waitForExistence(timeout: 5))
        app.buttons[strings.stats].tap()
        Thread.sleep(forTimeInterval: 1.0)
        snap("\(language)-03-stats")
        app.navigationBars.buttons.firstMatch.tap()

        // 04 — Meditation timer running.
        XCTAssertTrue(app.staticTexts[strings.meditationTimer].waitForExistence(timeout: 5))
        app.staticTexts[strings.meditationTimer].firstMatch.tap()
        XCTAssertTrue(app.buttons[strings.start].waitForExistence(timeout: 5))
        app.buttons[strings.start].tap()
        Thread.sleep(forTimeInterval: 2.0)
        snap("\(language)-04-meditation")
        app.buttons[strings.end].tap()

        // 05 — Settings (bonus material).
        XCTAssertTrue(app.buttons[strings.settings].waitForExistence(timeout: 5))
        app.buttons[strings.settings].tap()
        Thread.sleep(forTimeInterval: 1.0)
        snap("\(language)-05-settings")
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
