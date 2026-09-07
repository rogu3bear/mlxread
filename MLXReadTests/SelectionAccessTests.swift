import AppKit
import XCTest
@testable import MLXRead

private final class TestHotkey: GlobalHotkeyControlling {
    var isRunning = false
    var failuresRemaining = 0
    var becomesActive = true
    var startCount = 0
    var onStop: (() -> Void)?

    func start() throws {
        startCount += 1
        if failuresRemaining > 0 {
            failuresRemaining -= 1
            throw UserFacingSpeechError.hotkeyInstallFailed
        }
        isRunning = becomesActive
    }

    func stop() {
        isRunning = false
        onStop?()
    }
}

@MainActor
final class SelectionAccessTests: XCTestCase {
    func testMissingPermissionNeverStartsShortcut() {
        let hotkey = TestHotkey()
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { false })
        access.refresh()
        access.retryShortcut()

        XCTAssertFalse(access.isTrusted)
        XCTAssertFalse(access.shortcutActive)
        XCTAssertFalse(access.shortcutNeedsRetry)
        XCTAssertEqual(hotkey.startCount, 0)
    }

    func testGrantRetriesTransientFailureWithoutAnotherPermissionChange() {
        var trusted = false
        let hotkey = TestHotkey()
        hotkey.failuresRemaining = 1
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { trusted })
        var transitions: [Bool] = []
        access.onChange = { transitions.append($0) }

        trusted = true
        access.refresh()
        XCTAssertTrue(access.isTrusted)
        XCTAssertFalse(access.shortcutActive)

        access.refresh()
        XCTAssertTrue(access.shortcutActive)
        XCTAssertEqual(hotkey.startCount, 2)
        XCTAssertEqual(transitions, [true])
    }

    func testLostShortcutHealthRecoversWithoutSignallingPermissionChange() {
        let hotkey = TestHotkey()
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { true })
        access.onChange = { _ in XCTFail("Shortcut recovery is not a permission transition") }
        access.refresh()
        XCTAssertTrue(access.shortcutActive)

        hotkey.isRunning = false
        access.refresh()

        XCTAssertTrue(access.shortcutActive)
        XCTAssertEqual(hotkey.startCount, 2)
    }

    func testStartReturningWithoutAHealthyTapDoesNotReportReadyOrRetryForever() {
        let hotkey = TestHotkey()
        hotkey.becomesActive = false
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { true })

        for _ in 0..<10 { access.refresh() }

        XCTAssertFalse(access.shortcutActive)
        XCTAssertTrue(access.shortcutNeedsRetry)
        XCTAssertEqual(hotkey.startCount, 3)

        hotkey.becomesActive = true
        access.retryShortcut()

        XCTAssertTrue(access.shortcutActive)
        XCTAssertFalse(access.shortcutNeedsRetry)
        XCTAssertEqual(hotkey.startCount, 4)
    }

    func testRevocationStopsShortcutBeforeNotifyingAndRegrantRestoresIt() {
        var trusted = true
        let hotkey = TestHotkey()
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { trusted })
        access.refresh()
        var events: [String] = []
        hotkey.onStop = { events.append("stopped") }
        access.onChange = { granted in
            events.append(granted ? "granted" : "revoked")
            XCTAssertEqual(access.shortcutActive, granted)
        }

        trusted = false
        access.refresh()
        XCTAssertEqual(events, ["stopped", "revoked"])
        XCTAssertFalse(hotkey.isRunning)

        trusted = true
        access.refresh()
        XCTAssertTrue(access.shortcutActive)
        XCTAssertEqual(events, ["stopped", "revoked", "granted"])
    }

    func testHealthyRefreshDoesNotReinstallShortcut() {
        let hotkey = TestHotkey()
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { true })

        for _ in 0..<10 { access.refresh() }

        XCTAssertTrue(access.shortcutActive)
        XCTAssertEqual(hotkey.startCount, 1)
    }

    func testStoppingMonitorCannotReinstallShortcutAfterCancellation() async throws {
        let hotkey = TestHotkey()
        let access = SelectionAccessService(hotkey: hotkey, checkTrust: { true })
        access.startMonitoring()
        XCTAssertTrue(access.shortcutActive)

        access.stopMonitoring()
        try await Task.sleep(for: .milliseconds(1100))

        XCTAssertFalse(access.shortcutActive)
        XCTAssertFalse(hotkey.isRunning)
        XCTAssertEqual(hotkey.startCount, 1)
    }

    func testGrantClosesOnboardingAndPersistsCompletion() async throws {
        let suite = "SelectionAccessTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        var trusted = false
        let access = SelectionAccessService(hotkey: TestHotkey(), checkTrust: { trusted })
        let controller = OnboardingWindowController(access: access, settings: settings)
        controller.show()
        let window = try XCTUnwrap(NSApp.windows.first { $0.title == "MLXRead Setup" && $0.isVisible })
        defer { window.close() }
        window.contentView?.layoutSubtreeIfNeeded()
        XCTAssertFalse(settings.onboardingCompleted)

        let closed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            MainActor.assumeIsolated { !window.isVisible && settings.onboardingCompleted }
        }, object: nil)
        trusted = true
        access.refresh()
        await fulfillment(of: [closed], timeout: 3)

        XCTAssertTrue(AppSettings(defaults: defaults).onboardingCompleted)
    }
}
