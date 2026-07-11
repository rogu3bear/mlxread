import XCTest
@testable import MLXRead

final class TextNormalizerTests: XCTestCase {

    func testLineEndingNormalization() {
        let result = TextNormalizer.normalize("one\r\ntwo\rthree", maximumLength: 1000)
        XCTAssertEqual(result.text, "one\ntwo\nthree")
        XCTAssertFalse(result.wasTruncated)
    }

    func testControlCharacterRemoval() {
        let result = TextNormalizer.normalize("he\u{0000}llo\u{200B} wor\u{FEFF}ld", maximumLength: 1000)
        XCTAssertEqual(result.text, "hello world")
    }

    func testWhitespaceCollapse() {
        let result = TextNormalizer.normalize("a    b\t\tc", maximumLength: 1000)
        XCTAssertEqual(result.text, "a b c")
    }

    func testParagraphBoundariesPreserved() {
        let result = TextNormalizer.normalize("para one\n\n\n\npara two", maximumLength: 1000)
        XCTAssertEqual(result.text, "para one\n\npara two")
    }

    func testUnicodeSeparators() {
        let result = TextNormalizer.normalize("a\u{2028}b\u{2029}c", maximumLength: 1000)
        XCTAssertEqual(result.text, "a\nb\n\nc")
    }

    func testEmptySelection() {
        let result = TextNormalizer.normalize("   \n\t  ", maximumLength: 1000)
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(result.wasTruncated)
    }

    func testTruncationAtWordBoundary() {
        let text = Array(repeating: "word", count: 100).joined(separator: " ")
        let result = TextNormalizer.normalize(text, maximumLength: 50)
        XCTAssertTrue(result.wasTruncated)
        XCTAssertLessThanOrEqual(result.text.count, 50)
        XCTAssertFalse(result.text.hasSuffix(" "))
        XCTAssertTrue(result.text.hasSuffix("word"), "should cut at a word boundary, got: \(result.text.suffix(10))")
        XCTAssertEqual(result.originalLength, text.count)
    }

    func testNoTruncationUnderLimit() {
        let result = TextNormalizer.normalize("short text", maximumLength: 50)
        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(result.text, "short text")
    }

    func testNonBreakingSpace() {
        let result = TextNormalizer.normalize("a\u{00A0}b", maximumLength: 100)
        XCTAssertEqual(result.text, "a b")
    }

    func testDeterminism() {
        let input = "Some  text\r\nwith\u{200B} mixed \u{2028}issues.\n\n\n\nAnd more."
        let a = TextNormalizer.normalize(input, maximumLength: 500)
        let b = TextNormalizer.normalize(input, maximumLength: 500)
        XCTAssertEqual(a, b)
    }
}
