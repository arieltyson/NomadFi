import XCTest

final class NomadFiUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "UI_TEST_MODE": "1",
            "UI_TEST_RESET_STATE": "1",
            "UI_TEST_FORCE_REDUCE_MOTION": "1",
            "UI_TEST_HAS_COMPLETED_ONBOARDING": "1",
        ]
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
