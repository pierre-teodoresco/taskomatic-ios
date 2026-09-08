import XCTest

final class TaskomaticUITests: XCTestCase {
  override func setUpWithError() throws { continueAfterFailure = false }
  @MainActor
  func testTaskCanBeCreatedCompletedRestoredAndSurvivesRelaunch() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    let quickAdd = app.textFields["quickAdd"]
    XCTAssertTrue(quickAdd.waitForExistence(timeout: 10))
    quickAdd.tap()
    quickAdd.typeText("Acheter du café")
    app.buttons["quickAddSubmit"].tap()
    XCTAssertTrue(app.buttons["taskTitle.Acheter du café"].waitForExistence(timeout: 3))
    app.buttons["complete.Acheter du café"].tap()
    app.buttons["filter.completed"].tap()
    XCTAssertTrue(app.buttons["taskTitle.Acheter du café"].waitForExistence(timeout: 3))
    app.buttons["restore.Acheter du café"].tap()
    app.buttons["filter.active"].tap()
    XCTAssertTrue(app.buttons["taskTitle.Acheter du café"].waitForExistence(timeout: 3))
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-test-store" }
    app.launch()
    XCTAssertTrue(app.buttons["taskTitle.Acheter du café"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testRecurringTaskCanBeEditedAndWaitsAfterCompletion() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    app.buttons["newTaskDetails"].tap()
    let title = app.descendants(matching: .any)["editorTitle"].firstMatch
    XCTAssertTrue(title.waitForExistence(timeout: 5))
    title.tap()
    title.typeText("Arroser les plantes")
    let note = app.descendants(matching: .any)["editorNote"].firstMatch
    note.tap()
    note.typeText("Un peu d’eau suffit")
    app.swipeUp()
    app.buttons["editRecurrence"].tap()
    app.buttons["repeat.weekly"].tap()
    app.buttons["saveTask"].tap()
    XCTAssertTrue(app.buttons["taskTitle.Arroser les plantes"].waitForExistence(timeout: 4))
    app.buttons["complete.Arroser les plantes"].tap()
    XCTAssertTrue(app.buttons["restore.Arroser les plantes"].waitForExistence(timeout: 3))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "French recurring task waiting"
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  @MainActor
  func testLanguageAndAppearanceCanBeChanged() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    app.buttons["openSettings"].tap()
    let language = app.buttons["languagePicker"]
    XCTAssertTrue(language.waitForExistence(timeout: 5))
    language.tap()
    app.buttons["English"].tap()
    app.buttons["Dark"].tap()
    app.buttons["closeSettings"].tap()
    XCTAssertTrue(app.staticTexts["Your tasks"].waitForExistence(timeout: 3))
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "English dark appearance"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-test-store" }
    app.launch()
    XCTAssertTrue(app.staticTexts["Your tasks"].waitForExistence(timeout: 5))
  }

  @MainActor
  func testLocalNotificationArrivesWhileTheAppIsInTheBackground() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
      for title in ["Allow", "Autoriser", "Allow Notifications"] where alert.buttons[title].exists {
        alert.buttons[title].tap()
        return true
      }
      return false
    }
    app.launch()
    app.buttons["openSettings"].tap()
    app.switches["remindersToggle"].tap()
    app.tap()
    let testButton = app.buttons["testNotification"]
    XCTAssertTrue(testButton.waitForExistence(timeout: 8))
    testButton.tap()
    XCUIDevice.shared.press(.home)
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let banner = springboard.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Tes rappels sont prêts")).firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 12))
    let attachment = XCTAttachment(screenshot: springboard.screenshot())
    attachment.name = "Local reminder delivered with app backgrounded"
    attachment.lifetime = .keepAlways
    add(attachment)
    app.activate()
  }
}
