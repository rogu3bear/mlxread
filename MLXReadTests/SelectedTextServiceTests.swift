import os
import XCTest
@testable import MLXRead

/// Deterministic stand-ins so tests never touch the real pasteboard,
/// event taps, or the Accessibility API.
private final class StubReader: AXSelectionReading, ClipboardTextReading, @unchecked Sendable {
    private let count = OSAllocatedUnfairLock<Int>(initialState: 0)
    var callCount: Int { count.withLock { $0 } }
    let result: SelectionCaptureResult
    init(result: SelectionCaptureResult) { self.result = result }
    func captureSelection() async -> SelectionCaptureResult {
        count.withLock { $0 += 1 }
        return result
    }
}

@MainActor
final class SelectedTextServiceTests: XCTestCase {
    // MARK: - Raw clipboard mode

    func testRawFallbackReadsExistingClipboardWhenAXFails() async {
        let raw = StubReader(result: .text("clipboard text", source: .clipboard))
        let copy = StubReader(result: .noSelection)
        let service = makeService(
            ax: .unsupported,
            copy: copy,
            raw: raw,
            copyEnabled: false,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .text("clipboard text", source: .clipboard))
        XCTAssertEqual(copy.callCount, 0, "⌘C fallback must not run in raw mode")
    }

    func testRawFallbackKeepsAXResultWhenClipboardEmpty() async {
        let raw = StubReader(result: .noSelection)
        let service = makeService(
            ax: .noSelection,
            copy: StubReader(result: .noSelection),
            raw: raw,
            copyEnabled: false,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .noSelection)
    }

    func testRawFallbackKeepsAXDiagnosisForOtherFailures() async {
        let axResult = SelectionCaptureResult.failure(.axError(-25200))
        let raw = StubReader(result: .noSelection)
        let service = makeService(
            ax: .failure(.axError(-25200)),
            copy: StubReader(result: .noSelection),
            raw: raw,
            copyEnabled: false,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, axResult)
    }

    // MARK: - ⌘C mode (unchanged behavior, exclusivity)

    func testCopyFallbackTakesPrecedenceWhenBothEnabled() async {
        let copy = StubReader(result: .text("copied", source: .clipboard))
        let service = makeService(
            ax: .unsupported,
            copy: copy,
            raw: StubReader(result: .text("stale", source: .clipboard)),
            copyEnabled: true,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .text("copied", source: .clipboard))
        XCTAssertEqual(copy.callCount, 1)
    }

    func testCopyFallbackRunsWhenRawDisabled() async {
        let copy = StubReader(result: .text("copied", source: .clipboard))
        let service = makeService(
            ax: .noSelection,
            copy: copy,
            raw: StubReader(result: .noSelection),
            copyEnabled: true,
            rawEnabled: false
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .text("copied", source: .clipboard))
        XCTAssertEqual(copy.callCount, 1)
    }

    func testCopyFallbackFailureKeepsAXDiagnosis() async {
        let axResult = SelectionCaptureResult.applicationUnavailable
        let service = makeService(
            ax: .applicationUnavailable,
            copy: StubReader(result: .noSelection),
            raw: StubReader(result: .noSelection),
            copyEnabled: true,
            rawEnabled: false
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, axResult)
    }

    // MARK: - No fallback

    func testAXSuccessSkipsAllFallbacks() async {
        let copy = StubReader(result: .noSelection)
        let raw = StubReader(result: .text("stale", source: .clipboard))
        let service = makeService(
            ax: .text("selection", source: .accessibility),
            copy: copy,
            raw: raw,
            copyEnabled: true,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .text("selection", source: .accessibility))
        XCTAssertEqual(copy.callCount, 0)
        XCTAssertEqual(raw.callCount, 0)
    }

    func testPermissionDeniedNeverFallsBack() async {
        let copy = StubReader(result: .text("copied", source: .clipboard))
        let raw = StubReader(result: .text("stale", source: .clipboard))
        let service = makeService(
            ax: .permissionDenied,
            copy: copy,
            raw: raw,
            copyEnabled: true,
            rawEnabled: true
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .permissionDenied)
        XCTAssertEqual(copy.callCount, 0)
        XCTAssertEqual(raw.callCount, 0)
    }

    func testAllFallbacksDisabledReturnsAXResult() async {
        let copy = StubReader(result: .text("copied", source: .clipboard))
        let raw = StubReader(result: .text("stale", source: .clipboard))
        let service = makeService(
            ax: .unsupported,
            copy: copy,
            raw: raw,
            copyEnabled: false,
            rawEnabled: false
        )
        let result = await service.captureSelection()
        XCTAssertEqual(result, .unsupported)
        XCTAssertEqual(copy.callCount, 0)
        XCTAssertEqual(raw.callCount, 0)
    }

    // MARK: - Helpers

    private func makeService(
        ax: SelectionCaptureResult,
        copy: StubReader,
        raw: StubReader,
        copyEnabled: Bool,
        rawEnabled: Bool
    ) -> SelectedTextService {
        SelectedTextService(
            axReader: StubReader(result: ax),
            clipboardReader: copy,
            rawClipboardReader: raw,
            clipboardFallbackEnabled: { copyEnabled },
            rawClipboardFallbackEnabled: { rawEnabled }
        )
    }
}
