import Foundation
import XCTest

@MainActor
func makeUITestApplication(storeID: String = UUID().uuidString) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchEnvironment["VISIONTRACK_UI_TEST_STORE_ID"] = storeID
    return app
}
