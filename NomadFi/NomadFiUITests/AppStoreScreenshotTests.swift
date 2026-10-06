// AppStoreScreenshotTests.swift
// NomadFi
//
// Captures the raw App Store screenshots from the real app. Skipped in
// the normal suite; run on demand with:
//
//   TEST_RUNNER_APP_STORE_SCREENSHOTS=1 xcodebuild test \
//     -only-testing:NomadFiUITests/AppStoreScreenshotTests ...
//
// Each screen is kept as an attachment; App_Store/README.md describes
// how they become the framed listing images.

import XCTest

final class AppStoreScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["APP_STORE_SCREENSHOTS"] == "1",
            "App Store screenshots are captured on demand."
        )
        continueAfterFailure = false
    }

    @MainActor
    func testCaptureAppStoreScreens() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "UI_TEST_MODE": "1",
            "UI_TEST_RESET_STATE": "1",
            "UI_TEST_DISABLE_APP_LOCK": "1",
            "UI_TEST_HAS_COMPLETED_ONBOARDING": "1",
            "UI_TEST_SEED_SAMPLE_DATA": "1",
        ]
        app.launch()

        let tabs = app.tabBars
        XCTAssertTrue(tabs.buttons["Tools"].waitForExistence(timeout: 8))

        tabs.buttons["Tools"].tap()
        capture("06-tools", app)

        // Rates first: once a pair is on screen, the Dashboard's own
        // fetch has landed too, so no card is captured mid-load.
        open("Exchange Rates", in: app)
        let firstPair = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", " equals ")).firstMatch
        XCTAssertTrue(firstPair.waitForExistence(timeout: 20))
        capture("04-exchange-rates", app)

        open("Tax Vault", in: app, from: tabs.buttons["Tools"])
        capture("05-tax-vault", app)

        tabs.buttons["Dashboard"].tap()
        capture("01-dashboard", app)

        let canada = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Canada,")).firstMatch
        XCTAssertTrue(canada.waitForExistence(timeout: 8))
        canada.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 8))
        capture("02-country", app)

        tabs.buttons["Decisions"].tap()
        capture("03-decisions", app)
    }

    /// Opens a Tools row, first returning to the Tools root if given its tab.
    @MainActor
    private func open(_ title: String, in app: XCUIApplication, from tab: XCUIElement? = nil) {
        if let tab {
            tab.tap()
            tab.tap()
        }
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 8))
        row.tap()
    }

    /// Waits for the screen to settle, then keeps it.
    @MainActor
    private func capture(_ name: String, _ app: XCUIApplication) {
        _ = app.wait(for: .runningForeground, timeout: 2)
        Thread.sleep(forTimeInterval: 1.5)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
