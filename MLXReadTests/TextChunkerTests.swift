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
        // The trailing period ends the unit like a sentence.
        XCTAssertEqual(chunks.joined(), monster + ".")
    }

    func testDeterminism() {
        let text = "One. Two. Three.\n\nFour five six. Seven."
        XCTAssertEqual(TextChunker.chunk(text), TextChunker.chunk(text))
    }

    // MARK: - Pauses and sentence endings

    func testParagraphEndsGetParagraphPauseAndFinalChunkNone() {
        let chunks = TextChunker.chunks("First paragraph.\n\nSecond paragraph.\n\nThird.")
        XCTAssertEqual(chunks, [
            TextChunk(text: "First paragraph.", pauseAfter: .paragraph),
            TextChunk(text: "Second paragraph.", pauseAfter: .paragraph),
            TextChunk(text: "Third.", pauseAfter: .none),
        ])
    }

    func testChunksWithinAParagraphHaveNoPause() {
        let sentence = "This sentence is about fifty characters long okay."
        let paragraph = Array(repeating: sentence, count: 6).joined(separator: " ")
        let chunks = TextChunker.chunks(paragraph + "\n\nNext.", targetLength: 120, maximumLength: 200)
        XCTAssertGreaterThan(chunks.count, 2)
        XCTAssertEqual(chunks.dropLast(2).map(\.pauseAfter), Array(repeating: .none, count: chunks.count - 2))
        XCTAssertEqual(chunks[chunks.count - 2].pauseAfter, .paragraph)
    }

    func testHeadingGetsPeriod() {
        let chunks = TextChunker.chunks("Getting Started\n\nInstall the app.")
        XCTAssertEqual(chunks, [
            TextChunk(text: "Getting Started.", pauseAfter: .paragraph),
            TextChunk(text: "Install the app.", pauseAfter: .none),
        ])
    }

    func testBulletItemsStandAloneWithLinePauses() {
        let text = "Steps:\n- open the menu\n• choose Settings\n* done!\n\nAfter the list."
        XCTAssertEqual(TextChunker.chunks(text), [
            TextChunk(text: "Steps:", pauseAfter: .line),
            TextChunk(text: "open the menu.", pauseAfter: .line),
            TextChunk(text: "choose Settings.", pauseAfter: .line),
            TextChunk(text: "done!", pauseAfter: .paragraph),
            TextChunk(text: "After the list.", pauseAfter: .none),
        ])
    }

    func testSoftWrappedLinesJoin() {
        // Hard-wrapped text (PDFs, email) keeps reading as one sentence.
        XCTAssertEqual(TextChunker.chunks("There are books you can read about\nit at the library."),
                       [TextChunk(text: "There are books you can read about it at the library.", pauseAfter: .none)])
    }

    func testLineBreakAfterSentenceIsBoundary() {
        XCTAssertEqual(TextChunker.chunks("First line ends here.\nthen lowercase."), [
            TextChunk(text: "First line ends here.", pauseAfter: .line),
            TextChunk(text: "then lowercase.", pauseAfter: .none),
        ])
    }

    func testBrowserCopiedHeadingAndUnmarkedListGetLinePauses() {
        // Exact text Safari/Chrome copy from a rendered heading, paragraph,
        // list, and heading: single line breaks and no bullet markers.
        let text = "models degrade codebase quality over time\nI'm not going to say much more about maintainability. There are a bunch of books you can go read about it\n\nJohn Ousterhout's A Philosophy of Software Design\nRobert C. Martin's Clean Code\nMartin Fowler's Refactoring\n\"But surely the models have gotten better since then\"\n"
        let chunks = TextChunker.chunks(TextNormalizer.normalize(text, maximumLength: 10_000).text)
        XCTAssertEqual(chunks, [
            TextChunk(text: "models degrade codebase quality over time.", pauseAfter: .line),
            TextChunk(text: "I'm not going to say much more about maintainability. There are a bunch of books you can go read about it.", pauseAfter: .paragraph),
            TextChunk(text: "John Ousterhout's A Philosophy of Software Design.", pauseAfter: .line),
            TextChunk(text: "Robert C. Martin's Clean Code.", pauseAfter: .line),
            TextChunk(text: "Martin Fowler's Refactoring.", pauseAfter: .line),
            TextChunk(text: "\"But surely the models have gotten better since then\"", pauseAfter: .none),
        ])
    }

    func testHyphenWithoutSpaceIsNotABullet() {
        XCTAssertEqual(TextChunker.chunk("-5 degrees today."), ["-5 degrees today."])
    }

    func testUnitsEndingInSymbolsGetNoPeriod() {
        XCTAssertEqual(TextChunker.endingSentence("return []"), "return []")
        XCTAssertEqual(TextChunker.endingSentence("He said “hi”"), "He said “hi”")
        XCTAssertEqual(TextChunker.endingSentence("Version 2"), "Version 2.")
    }

    func testSilenceChunkLength() {
        let silence = SpeechAudioChunk.silence(seconds: ChunkPause.paragraph.seconds, sampleRate: 24_000, index: 3)
        XCTAssertEqual(silence?.samples.count, 14_400)
        XCTAssertEqual(silence?.index, 3)
        XCTAssertTrue(silence?.samples.allSatisfy { $0 == 0 } ?? false)
        XCTAssertNil(SpeechAudioChunk.silence(seconds: ChunkPause.none.seconds, sampleRate: 24_000, index: 0))
    }
}
