import Foundation
import XCTest

@MainActor
final class VisionRecordHistoryUITests: XCTestCase {
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
    private let recordPrefix = "visionRecordHistory.record."

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyHistoryReturnsToDashboard() throws {
        let app = launch()
        let history = openHistory(in: app)
        assertEmptyHistory(in: app)

        try goBack(from: history)
        XCTAssertTrue(element("dashboard.historyButton", in: app).waitForExistence(timeout: timeout))
    }

    func testHistoryOrdersRecordsAndOpensTheSelectedDetail() throws {
        let app = launch()
        saveRecord(left: "0.8", right: "1.2", in: app)
        saveRecord(left: "1.4", right: "0.6", in: app)

        let history = openHistory(in: app)
        let ids = assertEnglishHistory(leftValues: ["1.4", "0.8"], rightValues: ["0.6", "1.2"], in: app)
        app.buttons[ids[1]].tap()
        let detail = assertDetail(
            title: "Vision Record Details", dateLabel: "Examination Date and Time",
            left: "Left Eye, 0.8", right: "Right Eye, 1.2", in: app
        )

        try goBack(from: detail)
        XCTAssertTrue(history.waitForExistence(timeout: timeout))
        XCTAssertEqual(assertEnglishHistory(leftValues: ["1.4", "0.8"], rightValues: ["0.6", "1.2"], in: app), ids)
        try goBack(from: history)
        openHistory(in: app)
        XCTAssertEqual(assertEnglishHistory(leftValues: ["1.4", "0.8"], rightValues: ["0.6", "1.2"], in: app), ids)
    }

    func testHistoryPersistsAcrossProcessRestart() {
        let storeID = UUID().uuidString
        let app = launch(storeID: storeID)
        saveRecord(left: "0.8", right: "1.2", in: app)
        saveRecord(left: "1.4", right: "0.6", in: app)
        openHistory(in: app)
        let ids = assertEnglishHistory(leftValues: ["1.4", "0.8"], rightValues: ["0.6", "1.2"], in: app)

        terminate(app)
        let reopened = launch(storeID: storeID)
        openHistory(in: reopened)
        XCTAssertEqual(assertEnglishHistory(leftValues: ["1.4", "0.8"], rightValues: ["0.6", "1.2"], in: reopened), ids)
    }

    func testHistoryIsIsolatedByStoreID() {
        let firstStore = UUID().uuidString
        let secondStore = UUID().uuidString
        XCTAssertNotEqual(firstStore, secondStore)
        let first = launch(storeID: firstStore)
        saveRecord(left: "0.8", right: "1.2", in: first)
        openHistory(in: first)
        let ids = assertEnglishHistory(leftValues: ["0.8"], rightValues: ["1.2"], in: first)

        terminate(first)
        let second = launch(storeID: secondStore)
        openHistory(in: second)
        assertEmptyHistory(in: second)

        terminate(second)
        let reopened = launch(storeID: firstStore)
        openHistory(in: reopened)
        XCTAssertEqual(assertEnglishHistory(leftValues: ["0.8"], rightValues: ["1.2"], in: reopened), ids)
    }

    func testTraditionalChineseHistoryAndDetail() throws {
        let app = launch(language: .traditionalChinese)
        saveRecord(left: "0.8", right: "1.2", in: app)
        openHistory(title: "視力檢測歷史", in: app)

        let rows = historyRows(in: app)
        XCTAssertEqual(rows.count, 1)
        let row = try XCTUnwrap(rows.first)
        assertRow(row, contains: ["左眼 0.8", "右眼 1.2"])
        app.buttons[row.identifier].tap()
        assertDetail(
            title: "視力檢測紀錄詳情", dateLabel: "檢測日期與時間",
            left: "左眼、0.8", right: "右眼、1.2", in: app
        )
    }

    private func launch(storeID: String = UUID().uuidString, language: Language = .english) -> XCUIApplication {
        let app = makeUITestApplication(storeID: storeID)
        app.launchArguments = language.launchArguments
        app.launch()
        return app
    }

    private func terminate(_ app: XCUIApplication) {
        app.terminate()
        XCTAssertTrue(app.wait(for: .notRunning, timeout: timeout))
    }

    private func saveRecord(left: String, right: String, in app: XCUIApplication) {
        let add = app.buttons["dashboard.addVisionRecordButton"]
        XCTAssertTrue(add.waitForExistence(timeout: timeout))
        add.tap()

        let leftField = app.textFields["visionRecordEntry.leftEyeField"]
        let rightField = app.textFields["visionRecordEntry.rightEyeField"]
        XCTAssertTrue(leftField.waitForExistence(timeout: timeout))
        leftField.tap()
        leftField.typeText(left)
        rightField.tap()
        rightField.typeText(right)

        let save = app.buttons["visionRecordEntry.saveButton"]
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(leftField.waitForNonExistence(timeout: timeout))
        XCTAssertTrue(add.waitForExistence(timeout: timeout))
    }

    @discardableResult
    private func openHistory(title: String = "Vision Record History", in app: XCUIApplication) -> XCUIElement {
        let entry = element("dashboard.historyButton", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: timeout))
        entry.tap()

        let history = app.navigationBars[title]
        XCTAssertTrue(history.waitForExistence(timeout: timeout))
        return history
    }

    private func assertEmptyHistory(in app: XCUIApplication) {
        XCTAssertTrue(element("visionRecordHistory.emptyState", in: app).waitForExistence(timeout: timeout))
        XCTAssertFalse(element("visionRecordHistory.errorState", in: app).exists)
        XCTAssertFalse(element("visionRecordHistory.retryButton", in: app).exists)
    }

    private func historyRows(in app: XCUIApplication) -> [XCUIElement] {
        XCTAssertTrue(element("visionRecordHistory.list", in: app).waitForExistence(timeout: timeout))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", recordPrefix))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: timeout))
        return rows.allElementsBoundByIndex.sorted { $0.frame.minY < $1.frame.minY }
    }

    private func assertEnglishHistory(leftValues: [String], rightValues: [String], in app: XCUIApplication) -> [String] {
        let rows = historyRows(in: app)
        let ids = rows.map(\.identifier)
        XCTAssertEqual(rows.count, leftValues.count)
        XCTAssertEqual(Set(ids).count, rows.count)
        for (row, values) in zip(rows, zip(leftValues, rightValues)) {
            assertRow(row, contains: ["Left Eye \(values.0)", "Right Eye \(values.1)"])
        }
        return ids
    }

    private func assertRow(_ row: XCUIElement, contains eyeValues: [String]) {
        let uuid = String(row.identifier.dropFirst(recordPrefix.count))
        XCTAssertNotNil(UUID(uuidString: uuid))
        XCTAssertFalse(row.label.localizedCaseInsensitiveContains(uuid))
        for value in eyeValues {
            XCTAssertTrue(row.label.contains(value), "Expected \(value) in record label")
        }
    }

    @discardableResult
    private func assertDetail(
        title: String, dateLabel: String, left: String, right: String, in app: XCUIApplication
    ) -> XCUIElement {
        let detail = app.navigationBars[title]
        XCTAssertTrue(detail.waitForExistence(timeout: timeout))
        let date = element("visionRecordDetail.measuredAt", in: app)
        XCTAssertTrue(date.waitForExistence(timeout: timeout))
        XCTAssertTrue(date.label.hasPrefix(dateLabel))
        XCTAssertFalse(date.label.dropFirst(dateLabel.count).trimmingCharacters(in: .punctuationCharacters.union(.whitespaces)).isEmpty)
        XCTAssertEqual(element("visionRecordDetail.leftEye", in: app).label, left)
        XCTAssertEqual(element("visionRecordDetail.rightEye", in: app).label, right)
        return detail
    }

    private func goBack(from bar: XCUIElement) throws {
        let back = try XCTUnwrap(bar.buttons.allElementsBoundByIndex.first)
        XCTAssertTrue(back.isHittable)
        back.tap()
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
