import XCTest

/// Walks the main screens with seeded demo data and attaches a screenshot of
/// each — CI extracts these as artifacts so the app can be reviewed visually
/// without a device.
final class ScreenshotTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testCaptureMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitesting", "-hasCompletedOnboarding", "YES"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Wisho"].waitForExistence(timeout: 15), "Home should appear")
        snap(app, "01-home")

        // Send Sheet from the Today card.
        let sendButton = app.buttons["Send your wish"].firstMatch
        if sendButton.waitForExistence(timeout: 5) {
            sendButton.tap()
            let close = app.buttons["Close"].firstMatch
            _ = close.waitForExistence(timeout: 5)
            sleep(1) // let the sheet finish presenting so taps land reliably
            snap(app, "02-send-sheet")
            close.tap()
            // Wait until the sheet is actually gone before touching Home.
            if !sendButton.waitForExistence(timeout: 3) {
                app.swipeDown()
            }
        }

        // Person detail via an upcoming row.
        let samRow = app.staticTexts["Sam Rivera"].firstMatch
        if samRow.waitForExistence(timeout: 5) {
            samRow.tap()
            _ = app.navigationBars["Sam"].waitForExistence(timeout: 5)
            sleep(1)
            snap(app, "03-person-detail")
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = app.navigationBars["Wisho"].waitForExistence(timeout: 5)
        }

        // Settings.
        let settingsButton = app.buttons["settingsButton"].firstMatch
        if settingsButton.waitForExistence(timeout: 5) {
            settingsButton.tap()
            sleep(1)
            snap(app, "04-settings")
            let done = app.buttons["Done"].firstMatch
            if done.exists { done.tap() }
        }

        // Add person.
        let addButton = app.buttons["addPersonButton"].firstMatch
        if addButton.waitForExistence(timeout: 5) {
            addButton.tap()
            sleep(1)
            snap(app, "05-add-person")
            let cancel = app.buttons["Cancel"].firstMatch
            if cancel.exists { cancel.tap() }
        }

        // Onboarding (fresh launch with onboarding not completed).
        app.terminate()
        let fresh = XCUIApplication()
        fresh.launchArguments = ["--uitesting", "-hasCompletedOnboarding", "NO"]
        fresh.launch()
        sleep(2)
        snap(fresh, "06-onboarding")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
