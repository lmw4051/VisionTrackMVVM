//
//  VisionTrackMVVMUITests.swift
//  VisionTrackMVVMUITests
//
//  Created by David Lee on 11/2/26.
//

import XCTest

final class VisionTrackMVVMUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = makeUITestApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        let app = makeUITestApplication()
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
        }
        XCTAssertTrue(app.buttons["dashboard.addVisionRecordButton"].waitForExistence(timeout: 8))
    }
}

@MainActor
final class VisionRecordEntryUITests: XCTestCase {
    private enum Language {
        case english
        case traditionalChinese

        var launchArguments: [String] {
            switch self {
            case .english: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
            case .traditionalChinese: ["-AppleLanguages", "(zh-Hant)", "-AppleLocale", "zh_TW"]
            }
        }
    }

    private let timeout: TimeInterval = 8

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpensEntryForm() {
        let app = launch()
        openEntry(in: app)

        XCTAssertTrue(app.navigationBars["New Vision Record"].waitForExistence(timeout: timeout))
        XCTAssertTrue(leftEye(in: app).exists)
        XCTAssertTrue(rightEye(in: app).exists)
    }

    func testBlankFormDisablesSaveWithoutShowingRequiredErrors() {
        let app = launch()
        openEntry(in: app)

        assertEmpty(leftEye(in: app))
        assertEmpty(rightEye(in: app))
        XCTAssertFalse(saveButton(in: app).isEnabled)
        XCTAssertFalse(app.staticTexts["Required Field"].exists)
    }

    func testSavesValidRecordAndShowsLatestValuesOnDashboard() {
        let app = launch()
        assertEmptyDashboard(in: app)
        openEntry(in: app)
        enterValidRecord(in: app)

        let save = saveButton(in: app)
        XCTAssertTrue(save.isEnabled)
        save.tap()

        assertEntryDismissed(in: app)
        assertDashboardValue("0.8", for: "Left Eye", in: app)
        assertDashboardValue("1", for: "Right Eye", in: app)
        XCTAssertFalse(app.staticTexts["No examination records yet"].exists)
        XCTAssertTrue(app.staticTexts["Not Available Yet"].exists)
    }

    func testCancelDiscardsEnteredRecord() {
        let app = launch()
        assertEmptyDashboard(in: app)
        openEntry(in: app)
        enterValidRecord(in: app)
        XCTAssertTrue(saveButton(in: app).isEnabled)

        cancelButton(in: app).tap()

        assertEntryDismissed(in: app)
        assertEmptyDashboard(in: app)
    }

    func testInvalidValueShowsErrorAfterLosingFocusAndCannotSave() {
        let app = launch()
        openEntry(in: app)
        enter("2.01", in: leftEye(in: app))
        enter("1.0", in: rightEye(in: app))

        XCTAssertTrue(app.staticTexts["Out of Range"].waitForExistence(timeout: timeout))
        XCTAssertFalse(saveButton(in: app).isEnabled)

        cancelButton(in: app).tap()
        assertEntryDismissed(in: app)
        assertEmptyDashboard(in: app)
    }

    func testTraditionalChineseFormAndValidationMessage() {
        let app = launch(language: .traditionalChinese)
        openEntry(in: app)

        XCTAssertTrue(app.navigationBars["新增視力檢測紀錄"].waitForExistence(timeout: timeout))
        XCTAssertEqual(leftEye(in: app).placeholderValue, "左眼視力")
        XCTAssertEqual(rightEye(in: app).placeholderValue, "右眼視力")
        XCTAssertEqual(saveButton(in: app).label, "儲存")
        XCTAssertEqual(cancelButton(in: app).label, "取消")

        enter("2.01", in: leftEye(in: app))
        rightEye(in: app).tap()
        XCTAssertTrue(app.staticTexts["超出有效範圍"].waitForExistence(timeout: timeout))
        XCTAssertFalse(saveButton(in: app).isEnabled)
    }

    func testRecordSurvivesProcessRelaunchAndOtherStoreStaysEmpty() {
        let app = launch()
        assertEmptyDashboard(in: app)
        openEntry(in: app)
        enterValidRecord(in: app)
        saveButton(in: app).tap()
        assertEntryDismissed(in: app)
        assertDashboardValue("0.8", for: "Left Eye", in: app)
        assertDashboardValue("1", for: "Right Eye", in: app)

        app.terminate()
        XCTAssertEqual(app.state, .notRunning)
        app.launch()
        assertDashboardValue("0.8", for: "Left Eye", in: app)
        assertDashboardValue("1", for: "Right Eye", in: app)

        app.terminate()
        let otherStoreApp = launch()
        assertEmptyDashboard(in: otherStoreApp)
    }

    func testInvalidStoreIDShowsLocalizedErrorAndDoesNotOpenDashboard() {
        let app = launch(language: .traditionalChinese, storeID: "../invalid")
        let retry = app.buttons["visionRecordStore.retryButton"]
        XCTAssertTrue(retry.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["無法開啟檢測紀錄儲存空間"].exists)
        XCTAssertEqual(retry.label, "重試")
        XCTAssertFalse(addButton(in: app).exists)

        retry.tap()
        XCTAssertTrue(retry.waitForExistence(timeout: timeout))
        XCTAssertFalse(addButton(in: app).exists)
    }

    private func launch(language: Language = .english, storeID: String = UUID().uuidString) -> XCUIApplication {
        let app = makeUITestApplication(storeID: storeID)
        app.launchArguments = language.launchArguments
        app.launch()
        return app
    }

    private func openEntry(in app: XCUIApplication) {
        let add = addButton(in: app)
        XCTAssertTrue(add.waitForExistence(timeout: timeout))
        XCTAssertTrue(add.isEnabled)
        XCTAssertTrue(add.isHittable)
        add.tap()
        XCTAssertTrue(leftEye(in: app).waitForExistence(timeout: timeout))
        XCTAssertTrue(rightEye(in: app).exists)
        XCTAssertTrue(saveButton(in: app).exists)
    }

    private func enterValidRecord(in app: XCUIApplication) {
        enter("0.8", in: leftEye(in: app))
        enter("1.0", in: rightEye(in: app))
    }

    private func enter(_ value: String, in field: XCUIElement) {
        field.tap()
        field.typeText(value)
        XCTAssertEqual(field.value as? String, value)
    }

    private func assertEmpty(_ field: XCUIElement) {
        // XCTest can expose the placeholder as the value of an empty text field.
        let value = field.value as? String
        XCTAssertTrue(value == nil || value == "" || value == field.placeholderValue)
    }

    private func assertEntryDismissed(in app: XCUIApplication) {
        XCTAssertTrue(leftEye(in: app).waitForNonExistence(timeout: timeout))
        XCTAssertTrue(addButton(in: app).waitForExistence(timeout: timeout))
    }

    private func assertEmptyDashboard(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["No examination records yet"].waitForExistence(timeout: timeout))
    }

    private func assertDashboardValue(_ value: String, for label: String, in app: XCUIApplication) {
        // SwiftUI exposes LabeledContent as a combined accessibility label.
        let row = app.staticTexts["\(label), \(value)"]
        XCTAssertTrue(row.waitForExistence(timeout: timeout), "Expected \(label) to show \(value)")
    }

    private func addButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["dashboard.addVisionRecordButton"]
    }

    private func leftEye(in app: XCUIApplication) -> XCUIElement {
        app.textFields["visionRecordEntry.leftEyeField"]
    }

    private func rightEye(in app: XCUIApplication) -> XCUIElement {
        app.textFields["visionRecordEntry.rightEyeField"]
    }

    private func saveButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["visionRecordEntry.saveButton"]
    }

    private func cancelButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons["visionRecordEntry.cancelButton"]
    }
}
