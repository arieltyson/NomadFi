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

    @MainActor
    func tapButton(containing text: String, in app: XCUIApplication) {
        let predicate = NSPredicate(format: "label CONTAINS[c] %@", text)
        let button = app.buttons.matching(predicate).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 8))
        button.tap()
    }
}
