import XCTest

final class MLXReadUITests: XCTestCase {
    /// Smoke test: the app launches as a background (menu bar) utility and stays running.
    func testLaunchAsMenuBarUtility() {
        let app = XCUIApplication()
        app.launchEnvironment["MLXREAD_UITEST"] = "1"
        app.launch()
        // LSUIElement apps are .accessory; launch() returning without throwing
        // plus a running state check is the strongest assertion available here.
        XCTAssertTrue(app.state == .runningBackground || app.state == .runningForeground)
        app.terminate()
    }
}
