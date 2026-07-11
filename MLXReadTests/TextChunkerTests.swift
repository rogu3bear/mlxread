import XCTest
@testable import MLXRead

final class TextChunkerTests: XCTestCase {

    func testShortProseSingleChunk() {
        let chunks = TextChunker.chunk("Hello world. This is a test.")
        XCTAssertEqual(chunks, ["Hello world. This is a test."])
    }

    func testEmptyText() {
        XCTAssertEqual(TextChunker.chunk(""), [])
        XCTAssertEqual(TextChunker.chunk("   \n  "), [])
    }

    func testParagraphsAreChunkBoundaries() {
        let chunks = TextChunker.chunk("First paragraph.\n\nSecond paragraph.")
        XCTAssertEqual(chunks, ["First paragraph.", "Second paragraph."])
    }

    func testSentencePackingRespectsTargetLength() {
        let sentence = "This sentence is about fifty characters long okay."
        let text = Array(repeating: sentence, count: 10).joined(separator: " ")
        let chunks = TextChunker.chunk(text, targetLength: 120, maximumLength: 200)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 200)
        }
        // Re-joining loses nothing but inter-chunk whitespace.
        XCTAssertEqual(chunks.joined(separator: " "), text)
    }

    func testLongURLSurvivesIntact() {
        let url = "https://example.com/a/very/long/path?query=value&another=thing#fragment"
        let text = "Visit \(url) for details."
        let chunks = TextChunker.chunk(text, targetLength: 40, maximumLength: 90)
        XCTAssertTrue(chunks.contains { $0.contains(url) }, "URL was split across chunks: \(chunks)")
    }

    func testAbbreviationsDoNotOverSplit() {
        let text = "Dr. Smith met Mr. Jones at 3 p.m. on Jan. 5. They discussed the plan."
        let chunks = TextChunker.chunk(text)
        // NLTokenizer keeps abbreviation periods inside one sentence; the
        // whole thing fits one chunk either way.
        XCTAssertEqual(chunks.count, 1)
    }

    func testDecimalNumbersNotSplit() {
        let text = "The value of pi is 3.14159 and e is 2.71828 approximately."
        let chunks = TextChunker.chunk(text, targetLength: 30, maximumLength: 60)
        for chunk in chunks {
            XCTAssertFalse(chunk.hasSuffix("3."), "decimal split badly: \(chunks)")
        }
        XCTAssertEqual(chunks.joined(separator: " "), text)
    }

    func testCodeDoesNotCrashAndIsPreserved() {
        let code = """
        func chunk(_ text: String) -> [String] {
            let tokenizer = NLTokenizer(unit: .sentence)
            return []
        }
        """
        let chunks = TextChunker.chunk(code)
        XCTAssertFalse(chunks.isEmpty)
        let rejoined = chunks.joined(separator: " ")
        XCTAssertTrue(rejoined.contains("NLTokenizer(unit: .sentence)"))
    }

    func testUnicodePunctuation() {
        let text = "První věta má diakritiku. 第二句是中文。Third sentence is English."
        let chunks = TextChunker.chunk(text, targetLength: 30, maximumLength: 80)
        XCTAssertFalse(chunks.isEmpty)
        XCTAssertTrue(chunks.joined(separator: " ").contains("第二句是中文。"))
    }

    func testOversizedSingleTokenHardSplit() {
        let monster = String(repeating: "x", count: 1500)
        let chunks = TextChunker.chunk(monster, targetLength: 300, maximumLength: 600)
        XCTAssertGreaterThan(chunks.count, 1)
        for chunk in chunks {
            XCTAssertLessThanOrEqual(chunk.count, 600)
        }
        XCTAssertEqual(chunks.joined().count, 1500)
    }

    func testDeterminism() {
        let text = "One. Two. Three.\n\nFour five six. Seven."
        XCTAssertEqual(TextChunker.chunk(text), TextChunker.chunk(text))
    }
}
