import XCTest

/// Drives the main flow in the real app and attaches screenshots of each screen to the test
/// results (CI exports them as the "screenshots" artifact).
final class RepTrackUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor
    func testLogAWorkoutAndOpenProgress() {
        let app = XCUIApplication()
        // Starts with an empty, in-memory database
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 10))
        attachScreenshot(app, "01-empty-day")

        // Add an exercise
        app.buttons["addExerciseButton"].tap()
        let nameField = app.textFields["exerciseNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Bench Press")
        attachScreenshot(app, "02-add-exercise")
        app.buttons["confirmAddExercise"].tap()

        // Type a weight for the first set
        let weight = app.buttons["setWeight-1"]
        XCTAssertTrue(weight.waitForExistence(timeout: 5))
        weight.tap()
        let weightField = app.textFields["setWeightField"]
        XCTAssertTrue(weightField.waitForExistence(timeout: 5))
        weightField.typeText("60")
        attachScreenshot(app, "03-edit-set")
        app.navigationBars["Set 1"].buttons["Save"].tap()

        // Tick the first two sets off; the rest timer starts automatically
        let firstSet = app.buttons["Set 1 done"]
        XCTAssertTrue(firstSet.waitForExistence(timeout: 5))
        firstSet.tap()
        app.buttons["Set 2 done"].tap()
        XCTAssertTrue(app.staticTexts["REST"].waitForExistence(timeout: 5))
        attachScreenshot(app, "04-workout-logged")

        // Progress report
        app.buttons["Progress"].tap()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Progressive overload"].waitForExistence(timeout: 5))
        attachScreenshot(app, "05-progress")

        app.buttons["Month"].tap()
        attachScreenshot(app, "06-progress-month")
    }

    @MainActor
    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
