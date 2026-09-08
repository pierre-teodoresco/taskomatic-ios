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
  func testTappingThePageDismissesQuickAddKeyboardAndKeepsTheDraft() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    let quickAdd = app.textFields["quickAdd"]
    XCTAssertTrue(quickAdd.waitForExistence(timeout: 10))
    quickAdd.tap()
    quickAdd.typeText("Préparer le voyage")
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))

    // Touch the page gutter immediately above the composer, outside any control.
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 12, dy: quickAdd.frame.minY - 40)).tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    XCTAssertEqual(quickAdd.value as? String, "Préparer le voyage")
    XCTAssertFalse(app.buttons["taskTitle.Préparer le voyage"].exists)

    quickAdd.tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
    quickAdd.typeText(" cet été")
    // Page controls must still work while dismissing the keyboard.
    app.buttons["filter.completed"].tap()
    XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
    XCTAssertTrue(app.buttons["filter.completed"].isSelected)
    XCTAssertEqual(quickAdd.value as? String, "Préparer le voyage cet été")
    app.buttons["filter.active"].tap()
    XCTAssertFalse(app.buttons["taskTitle.Préparer le voyage cet été"].exists)

    app.buttons["quickAddSubmit"].tap()
    XCTAssertTrue(app.buttons["taskTitle.Préparer le voyage cet été"].waitForExistence(timeout: 3))
    XCTAssertEqual(
      app.buttons.matching(identifier: "taskTitle.Préparer le voyage cet été").count, 1)
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
  func testRecurrenceCanBeSelectedAcrossTheEntireRow() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    app.buttons["newTaskDetails"].tap()
    app.buttons["editRecurrence"].tap()
    let weekly = app.buttons["repeat.weekly"]
    XCTAssertTrue(weekly.waitForExistence(timeout: 5))
    // Hit the empty trailing portion of the card, independently of the label's bounds.
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: app.frame.maxX - 32, dy: weekly.frame.midY)).tap()
    XCTAssertTrue(app.buttons["editRecurrence"].waitForExistence(timeout: 3))

    app.buttons["editRecurrence"].tap()
    XCTAssertTrue(weekly.waitForExistence(timeout: 3))
    XCTAssertTrue(weekly.isSelected)
    XCTAssertFalse(app.buttons["repeat.monthly"].isSelected)
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Selected recurrence uses the accent color"
    attachment.lifetime = .keepAlways
    add(attachment)

    // The leading padding of another option is also part of its touch target.
    let monthly = app.buttons["repeat.monthly"]
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 28, dy: monthly.frame.midY)).tap()
    XCTAssertTrue(app.buttons["editRecurrence"].waitForExistence(timeout: 3))
    app.buttons["editRecurrence"].tap()
    XCTAssertTrue(monthly.waitForExistence(timeout: 3))
    XCTAssertTrue(monthly.isSelected)
    XCTAssertFalse(weekly.isSelected)
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
  func testSettingsThemeChangesRepeatedlyWithoutClosingTheSheet() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--ui-testing", "--reset-test-store", "-AppleLanguages", "(fr)", "-AppleLocale", "fr_FR",
    ]
    app.launch()
    app.buttons["openSettings"].tap()
    let systemBrightness = try XCTUnwrap(settingsBackgroundBrightness(in: app))
    app.buttons["Sombre"].tap()
    app.buttons["closeSettings"].tap()
    app.buttons["openSettings"].tap()

    let changes = [
      ("Clair", false), ("Sombre", true), ("Clair", false), ("Sombre", true),
      (systemBrightness < 0.5 ? "Clair" : "Sombre", systemBrightness >= 0.5),
      ("Système", systemBrightness < 0.5),
    ]
    for (label, dark) in changes {
      app.segmentedControls["appearancePicker"].buttons[label].tap()
      let appearanceChanged = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in
          guard let brightness = self.settingsBackgroundBrightness(in: app) else { return false }
          return dark ? brightness < 0.25 : brightness > 0.75
        }, object: nil)
      let result = XCTWaiter.wait(for: [appearanceChanged], timeout: 5)
      let attachment = XCTAttachment(screenshot: app.screenshot())
      attachment.name = "Settings after selecting \(label)"
      attachment.lifetime = .keepAlways
      add(attachment)
      XCTAssertEqual(result, .completed, "The open settings sheet must immediately become \(label)")
      XCTAssertTrue(app.buttons["closeSettings"].exists)
    }
  }

  @MainActor
  private func settingsBackgroundBrightness(in app: XCUIApplication) -> Double? {
    // Sample the visible sheet gutter, outside cards and text. Assert the rendered
    // appearance rather than the saved preference or selected segment.
    guard let image = app.screenshot().image.cgImage,
      let pixel = image.cropping(
        to: CGRect(
          x: CGFloat(image.width) * 0.03, y: CGFloat(image.height) * 0.5, width: 1, height: 1))
    else { return nil }
    var rgba = [UInt8](repeating: 0, count: 4)
    let sampled = rgba.withUnsafeMutableBytes { bytes in
      guard
        let context = CGContext(
          data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
      else { return false }
      context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
      return true
    }
    guard sampled else { return nil }
    return (Double(rgba[0]) + Double(rgba[1]) + Double(rgba[2])) / (3 * 255)
  }

  @MainActor
  func testLocalNotificationArrivesWhileSettingsRemainOpen() throws {
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
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
    let banner = springboard.descendants(matching: .any)
      .matching(NSPredicate(format: "label CONTAINS %@", "Tes rappels sont prêts")).firstMatch
    XCTAssertTrue(banner.waitForExistence(timeout: 12))
    XCTAssertEqual(app.state, .runningForeground)
    let attachment = XCTAttachment(screenshot: springboard.screenshot())
    attachment.name = "Test reminder with settings still open"
    attachment.lifetime = .keepAlways
    add(attachment)

    // The preview must remain in Notification Center after a foreground refresh.
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-test-store" }
    app.launch()
    XCUIDevice.shared.press(.home)
    springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.01))
      .press(
        forDuration: 0.1,
        thenDragTo:
          springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.8)))
    XCTAssertTrue(banner.waitForExistence(timeout: 5))
    XCUIDevice.shared.press(.home)
    app.activate()
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
