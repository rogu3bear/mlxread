import AppKit
import XCTest
@testable import MLXRead

@MainActor
final class PasteboardSnapshotTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        // Unique named pasteboard: tests never touch the user's clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("me.jkca.mlxread.tests.\(UUID().uuidString)"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    func testCaptureAndRestoreRoundTripPreservesTypes() {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString("hello", forType: .string)
        item.setData(Data([0x25, 0x50, 0x44, 0x46]), forType: NSPasteboard.PasteboardType("com.adobe.pdf"))
        pasteboard.writeObjects([item])

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        XCTAssertEqual(snapshot.items.count, 1)

        // Simulate our own ⌘C overwriting the pasteboard.
        pasteboard.clearContents()
        pasteboard.setString("copied selection", forType: .string)
        let afterCopy = pasteboard.changeCount

        let restored = snapshot.restore(to: pasteboard, ifChangeCountEquals: afterCopy)
        XCTAssertTrue(restored)
        XCTAssertEqual(pasteboard.string(forType: .string), "hello")
        XCTAssertEqual(
            pasteboard.pasteboardItems?.first?.data(forType: NSPasteboard.PasteboardType("com.adobe.pdf")),
            Data([0x25, 0x50, 0x44, 0x46])
        )
    }

    func testRestoreRefusedWhenPasteboardChangedExternally() {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        // Our copy...
        pasteboard.clearContents()
        pasteboard.setString("selection", forType: .string)
        let afterCopy = pasteboard.changeCount

        // ...then the user copies something else before we restore.
        pasteboard.clearContents()
        pasteboard.setString("user's own copy", forType: .string)

        let restored = snapshot.restore(to: pasteboard, ifChangeCountEquals: afterCopy)
        XCTAssertFalse(restored, "must not clobber external pasteboard writes")
        XCTAssertEqual(pasteboard.string(forType: .string), "user's own copy")
    }

    func testEmptyPasteboardRoundTrip() {
        pasteboard.clearContents()
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        XCTAssertTrue(snapshot.items.isEmpty)

        pasteboard.setString("temp", forType: .string)
        let afterCopy = pasteboard.changeCount
        let restored = snapshot.restore(to: pasteboard, ifChangeCountEquals: afterCopy)
        XCTAssertTrue(restored)
        XCTAssertNil(pasteboard.string(forType: .string), "restore of empty snapshot leaves pasteboard cleared")
    }

    func testMultipleItemsPreserved() {
        pasteboard.clearContents()
        let a = NSPasteboardItem()
        a.setString("first", forType: .string)
        let b = NSPasteboardItem()
        b.setString("second", forType: .string)
        pasteboard.writeObjects([a, b])

        let snapshot = PasteboardSnapshot.capture(from: pasteboard)
        XCTAssertEqual(snapshot.items.count, 2)

        pasteboard.clearContents()
        pasteboard.setString("overwrite", forType: .string)
        let afterCopy = pasteboard.changeCount
        XCTAssertTrue(snapshot.restore(to: pasteboard, ifChangeCountEquals: afterCopy))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 2)
    }
}
