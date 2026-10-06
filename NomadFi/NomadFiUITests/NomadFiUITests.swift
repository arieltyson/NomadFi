import XCTest

final class NomadFiUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingCompletionFlow() {
        let app = makeApp(hasCompletedOnboarding: false)
        app.launch()

        XCTAssertTrue(app.buttons["Get Started"].waitForExistence(timeout: 8))
        app.buttons["Get Started"].tap()

        tapButton(containing: "Trinidad", in: app)
        tapButton(containing: "Canada", in: app)

        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 8))
        app.buttons["Continue"].tap()

        tapButton(containing: "Canadian Dollar", in: app)
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 8))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.buttons["Finish Setup"].waitForExistence(timeout: 8))
        app.buttons["Finish Setup"].tap()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testAddTransactionFlow() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        tapButton(containing: "Ledger", in: app)

        let addTransaction = app.navigationBars["Ledger"].buttons["Add Transaction"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 8))
        addTransaction.tap()

        XCTAssertTrue(app.textFields["Merchant Name"].waitForExistence(timeout: 8))
        app.textFields["Merchant Name"].tap()
        app.textFields["Merchant Name"].typeText("Coffee Shop UI Test")

        XCTAssertTrue(app.textFields["Amount"].waitForExistence(timeout: 8))
        app.textFields["Amount"].tap()
        app.textFields["Amount"].typeText("12.50")

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 8))
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Coffee Shop UI Test"].waitForExistence(timeout: 8))
    }

    /// Country cards are alphabetical, and each opens its country.
    @MainActor
    func testCountryCardsOpenTheirCountry() {
        let app = makeApp(
            hasCompletedOnboarding: true,
            extraEnvironment: ["UI_TEST_SEED_SAMPLE_DATA": "1"]
        )
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Dashboard"].tap()

        let canada = countryCard(named: "Canada", in: app)
        let unitedStates = countryCard(named: "United States", in: app)
        XCTAssertTrue(canada.waitForExistence(timeout: 8))
        XCTAssertTrue(unitedStates.waitForExistence(timeout: 8))
        XCTAssertLessThan(canada.frame.minY, unitedStates.frame.minY)

        canada.tap()
        XCTAssertTrue(
            app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS %@", "Canada"))
                .firstMatch
                .waitForExistence(timeout: 8)
        )

        keepScreenshot(named: "Country page", of: app)
    }

    /// + captures a decision; touch and hold offers Apple Intelligence.
    @MainActor
    func testCaptureDecisionFromToolbar() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Decisions"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Decisions"].tap()

        let capture = app.buttons["decisions.capture"]
        XCTAssertTrue(capture.waitForExistence(timeout: 8))

        // XCUITest's synthesised press needs longer than a person's
        // touch-and-hold before the menu replaces the primary action.
        capture.press(forDuration: 2)
        XCTAssertTrue(app.buttons["Describe with Apple Intelligence"].waitForExistence(timeout: 8))
        app.tap()

        capture.tap()
        XCTAssertTrue(app.navigationBars["Capture decision"].waitForExistence(timeout: 8))
    }

    /// Investing Learn shows a card per jurisdiction, each opening
    /// that region's lessons.
    @MainActor
    func testInvestingLearnRegionCardsOpenTheirRegion() {
        let app = makeApp(
            hasCompletedOnboarding: true,
            extraEnvironment: ["UI_TEST_SEED_SAMPLE_DATA": "1"]
        )
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()
        tapButton(containing: "Investing Learn", in: app)
        keepScreenshot(named: "Investing Learn", of: app)

        tapButton(containing: "Canada", in: app)
        XCTAssertTrue(
            app.navigationBars.matching(NSPredicate(format: "identifier CONTAINS %@", "Canada"))
                .firstMatch
                .waitForExistence(timeout: 8)
        )
        keepScreenshot(named: "Investing region", of: app)
    }

    /// Accounts live on their own page; Edit selects several, and a
    /// centred alert confirms deleting them.
    @MainActor
    func testDeleteSeveralAccountsWithOneConfirmation() {
        let app = makeApp(
            hasCompletedOnboarding: true,
            extraEnvironment: ["UI_TEST_SEED_SAMPLE_DATA": "1"]
        )
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Settings"].tap()
        tapButton(containing: "Financial Setup", in: app)
        tapButton(containing: "Accounts", in: app)
        XCTAssertTrue(app.navigationBars["Accounts"].waitForExistence(timeout: 8))

        let rows = app.collectionViews.firstMatch.cells
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 8))
        let countBefore = rows.count
        XCTAssertGreaterThanOrEqual(countBefore, 2)

        app.navigationBars["Accounts"].buttons["Edit"].tap()
        rows.element(boundBy: 0).tap()
        rows.element(boundBy: 1).tap()
        keepScreenshot(named: "Accounts selecting", of: app)
        app.buttons["Delete"].firstMatch.tap()

        let alert = app.alerts["Delete 2 Accounts?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 8))
        alert.buttons["Delete"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: 8))
        XCTAssertEqual(rows.count, countBefore - 2)
    }

    @MainActor
    func testExchangeRatesOpenFromTools() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        tapButton(containing: "Exchange Rates", in: app)
        XCTAssertTrue(app.navigationBars["Exchange Rates"].waitForExistence(timeout: 8))
    }

    /// The keyboard's Done button must survive every focus change, not
    /// just the first — the decimal pad has no other way out.
    @MainActor
    func testKeyboardDoneSurvivesRepeatedFocusChanges() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        tapButton(containing: "Ledger", in: app)

        let addTransaction = app.navigationBars["Ledger"].buttons["Add Transaction"]
        XCTAssertTrue(addTransaction.waitForExistence(timeout: 8))
        addTransaction.tap()

        let merchant = app.textFields["Merchant Name"]
        let amount = app.textFields["Amount"]
        let done = app.buttons["keyboard.done"]
        XCTAssertTrue(merchant.waitForExistence(timeout: 8))

        for field in [merchant, amount, merchant, amount] {
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 8))
            XCTAssertTrue(done.waitForExistence(timeout: 8))
            done.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 8))
        }
    }

    @MainActor
    func testReceiptConfirmationFlow() {
        let app = makeApp(
            hasCompletedOnboarding: true,
            extraEnvironment: [
                "UI_TEST_SHOW_RECEIPT_CONFIRMATION": "1"
            ]
        )
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        tapButton(containing: "Tax Vault", in: app)

        XCTAssertTrue(app.navigationBars["Confirm Receipt"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 8))
        app.buttons["Save"].tap()

        XCTAssertTrue(app.navigationBars["Tax Vault"].waitForExistence(timeout: 8))

        // Saved documents are listed on the Archive surface; Tax Vault
        // opens on Review.
        let archive = app.segmentedControls.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Archive"))
            .firstMatch
        XCTAssertTrue(archive.waitForExistence(timeout: 8))
        archive.tap()

        // Each row is one combined accessibility element, so match the
        // merchant at the start of its label rather than a static text.
        let savedReceipt = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "UITest Market,"))
            .firstMatch
        XCTAssertTrue(savedReceipt.waitForExistence(timeout: 8))
    }

    @MainActor
    func testAddSubscriptionFlow() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Tools"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Tools"].tap()

        tapButton(containing: "Subscriptions", in: app)

        let addSubscription = app.navigationBars["Subscriptions"].buttons["Add Subscription"]
        XCTAssertTrue(addSubscription.waitForExistence(timeout: 8))
        addSubscription.tap()

        XCTAssertTrue(app.textFields["Service name"].waitForExistence(timeout: 8))
        app.textFields["Service name"].tap()
        app.textFields["Service name"].typeText("Streaming UI Test")

        XCTAssertTrue(app.textFields["Amount"].waitForExistence(timeout: 8))
        app.textFields["Amount"].tap()
        app.textFields["Amount"].typeText("14.99")

        XCTAssertTrue(app.buttons["Save"].waitForExistence(timeout: 8))
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Streaming UI Test"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSettingsPrivacyPolicyFlow() {
        let app = makeApp(hasCompletedOnboarding: true)
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Settings"].tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))

        tapButton(containing: "Privacy & Security", in: app)
        XCTAssertTrue(app.navigationBars["Privacy & Security"].waitForExistence(timeout: 8))

        XCTAssertTrue(app.buttons["Privacy Policy"].waitForExistence(timeout: 8))
        app.buttons["Privacy Policy"].tap()

        XCTAssertTrue(app.navigationBars["Privacy Policy"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 8))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.navigationBars["Privacy & Security"].waitForExistence(timeout: 8))
    }
}

private extension NomadFiUITests {

    @MainActor
    func makeApp(
        hasCompletedOnboarding: Bool,
        extraEnvironment: [String: String] = [:]
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "UI_TEST_MODE": "1",
            "UI_TEST_RESET_STATE": "1",
            "UI_TEST_DISABLE_APP_LOCK": "1",
            "UI_TEST_FORCE_REDUCE_MOTION": "1",
            "UI_TEST_HAS_COMPLETED_ONBOARDING": hasCompletedOnboarding ? "1" : "0",
        ].merging(extraEnvironment) { _, newValue in newValue }

        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityL"
        ]

        return app
    }

    /// Keeps a screenshot with the result, for reviewing a layout.
    @MainActor
    func keepScreenshot(named name: String, of app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func countryCard(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name),")).firstMatch
    }

    @MainActor
    func tapButton(containing text: String, in app: XCUIApplication) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let button = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        button.tap()
    }
}
