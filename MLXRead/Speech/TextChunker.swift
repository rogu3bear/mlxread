import Foundation
import NaturalLanguage

/// Silence to insert after a chunk.
enum ChunkPause: Equatable, Sendable {
    case none
    /// After a line break within a paragraph.
    case line
    /// After the last chunk of a paragraph.
    case paragraph

    /// Silence length at normal speaking speed.
    var seconds: Double {
        switch self {
        case .none: return 0
        case .line: return 0.25
        case .paragraph: return 0.6
        }
    }
}

/// A chunk of text to synthesize, with the pause that follows it.
struct TextChunk: Equatable, Sendable {
    let text: String
    var pauseAfter: ChunkPause
}

/// Deterministic sentence/paragraph chunking for incremental synthesis.
///
/// Paragraph and line boundaries are always chunk boundaries. Within
/// a unit, sentences (via `NLTokenizer`) are packed into chunks up to `targetLength`.
/// A single sentence longer than `maximumLength` is hard-split at word
/// boundaries; URLs and decimal numbers survive because NLTokenizer treats
/// them as sentence-internal tokens and word-boundary splitting never breaks
/// a non-whitespace run.
enum TextChunker {
    static let defaultTargetLength = 300
    static let defaultMaximumLength = 600

    /// Text of each chunk, in order. See `chunks(_:targetLength:maximumLength:)`
    /// for the pause that should follow each one.
    static func chunk(
        _ text: String,
        targetLength: Int = defaultTargetLength,
        maximumLength: Int = defaultMaximumLength
    ) -> [String] {
        chunks(text, targetLength: targetLength, maximumLength: maximumLength).map(\.text)
    }

    /// Chunks with the pause to insert after each.
    ///
    /// A paragraph is split into units: each line is its own unit, except
    /// soft-wrapped lines (see `isSoftWrap`), which join into one. A unit
    /// that ends without terminal punctuation (a heading or list item) gets a
    /// period so the voice ends it with falling intonation. The last chunk of
    /// a unit is followed by a `.line` pause, or `.paragraph` at the end of a
    /// paragraph. The final chunk never has a pause.
    static func chunks(
        _ text: String,
        targetLength: Int = defaultTargetLength,
        maximumLength: Int = defaultMaximumLength
    ) -> [TextChunk] {
        guard !text.isEmpty else { return [] }
        precondition(targetLength > 0 && maximumLength >= targetLength)

        var result: [TextChunk] = []
        let paragraphs = text.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let para = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !para.isEmpty else { continue }

            let units = self.units(in: para)
            for (unitIndex, unit) in units.enumerated() {
                let pieces = sentenceChunks(unit, targetLength: targetLength, maximumLength: maximumLength)
                guard !pieces.isEmpty else { continue }
                result.append(contentsOf: pieces.map { TextChunk(text: $0, pauseAfter: .none) })
                let pause: ChunkPause = unitIndex == units.count - 1 ? .paragraph : .line
                result[result.count - 1].pauseAfter = pause
            }
        }
        if !result.isEmpty {
            result[result.count - 1].pauseAfter = .none
        }
        return result
    }

    /// Splits a paragraph into speakable units: each line is its own unit
    /// (bullet marker removed), except soft-wrapped lines, which join with a
    /// space.
    static func units(in paragraph: String) -> [String] {
        var units: [String] = []
        var prose: [String] = []
        func flushProse() {
            if !prose.isEmpty {
                units.append(prose.joined(separator: " "))
                prose = []
            }
        }
        for rawLine in paragraph.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            if let item = bulletItem(line) {
                flushProse()
                if !item.isEmpty { units.append(item) }
            } else if let previous = prose.last, isSoftWrap(previous, line) {
                prose.append(line)
            } else {
                flushProse()
                prose.append(line)
            }
        }
        flushProse()
        return units.map(endingSentence)
    }

    /// True when `next` continues `previous` after a hard wrap: the previous
    /// line has no sentence-ending punctuation and the next starts lowercase.
    /// Any other line break is a line boundary. Browsers copy headings and
    /// unmarked list items this way, one per line.
    static func isSoftWrap(_ previous: String, _ next: String) -> Bool {
        guard let first = next.first, first.isLowercase else { return false }
        guard let last = previous.last else { return true }
        return !".!?…:;。！？".contains(last)
    }

    /// The item text if `line` starts with a symbol bullet, else nil.
    /// Numbered items ("1.") are left as prose; their numbers are worth saying.
    static func bulletItem(_ line: String) -> String? {
        guard let range = line.range(of: #"^[-*•‣◦▪▫●○■□–—]\s+"#, options: .regularExpression) else {
            return nil
        }
        return String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
    }

    /// Appends a period when a unit ends in a letter or digit, so headings and
    /// list items end like sentences. Units ending in punctuation, closing
    /// brackets, or code symbols are left alone.
    static func endingSentence(_ unit: String) -> String {
        guard let last = unit.unicodeScalars.last,
              CharacterSet.alphanumerics.contains(last) else { return unit }
        return unit + "."
    }

    /// Packs a unit's sentences into chunks up to `targetLength`, hard-splitting
    /// sentences longer than `maximumLength`.
    private static func sentenceChunks(_ unit: String, targetLength: Int, maximumLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for sentence in sentences(in: unit) {
            if sentence.count > maximumLength {
                if !current.isEmpty {
                    chunks.append(current)
                    current = ""
                }
                chunks.append(contentsOf: hardSplit(sentence, maximumLength: maximumLength))
                continue
            }
            if current.isEmpty {
                current = sentence
            } else if current.count + 1 + sentence.count <= targetLength {
                current += " " + sentence
            } else {
                chunks.append(current)
                current = sentence
            }
        }
        if !current.isEmpty {
            chunks.append(current)
        }
        return chunks
    }

    /// Sentence segmentation via NLTokenizer; deterministic for a given input.
    ///
    /// A merge pass repairs boundaries the tokenizer places mid-token (it
    /// splits URLs at `?`, for example): when the character immediately
    /// before a boundary is not whitespace, the split happened inside a
    /// non-whitespace run and the two pieces are rejoined.
    static func sentences(in paragraph: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = paragraph
        var ranges: [Range<String.Index>] = []
        tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
            ranges.append(range)
            return true
        }

        var merged: [Range<String.Index>] = []
        for range in ranges {
            if let last = merged.last,
               last.upperBound == range.lowerBound,
               range.lowerBound > paragraph.startIndex {
                let before = paragraph.index(before: range.lowerBound)
                if !paragraph[before].isWhitespace {
                    merged[merged.count - 1] = last.lowerBound..<range.upperBound
                    continue
                }
            }
            merged.append(range)
        }

        let result = merged.compactMap { range -> String? in
            let sentence = paragraph[range].trimmingCharacters(in: .whitespacesAndNewlines)
            return sentence.isEmpty ? nil : sentence
        }
        if result.isEmpty {
            let trimmed = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [trimmed]
        }
        return result
    }

    /// Splits an overlong sentence at whitespace, never inside a
    /// non-whitespace run (so URLs, numbers, and identifiers stay intact —
    /// unless a single token itself exceeds `maximumLength`, in which case it
    /// is split by character count as a last resort).
    static func hardSplit(_ sentence: String, maximumLength: Int) -> [String] {
        var pieces: [String] = []
        var current = ""
        for word in sentence.split(separator: " ", omittingEmptySubsequences: true) {
            let w = String(word)
            if w.count > maximumLength {
                if !current.isEmpty {
                    pieces.append(current)
                    current = ""
                }
                var rest = Substring(w)
                while rest.count > maximumLength {
                    let cut = rest.index(rest.startIndex, offsetBy: maximumLength)
                    pieces.append(String(rest[..<cut]))
                    rest = rest[cut...]
                }
                current = String(rest)
                continue
            }
            if current.isEmpty {
                current = w
            } else if current.count + 1 + w.count <= maximumLength {
                current += " " + w
            } else {
                pieces.append(current)
                current = w
            }
        }
        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces
    }
}
