import Foundation
import NaturalLanguage

/// Deterministic sentence/paragraph chunking for incremental synthesis.
///
/// Paragraph boundaries are always chunk boundaries. Within a paragraph,
/// sentences (via `NLTokenizer`) are packed into chunks up to `targetLength`.
/// A single sentence longer than `maximumLength` is hard-split at word
/// boundaries; URLs and decimal numbers survive because NLTokenizer treats
/// them as sentence-internal tokens and word-boundary splitting never breaks
/// a non-whitespace run.
enum TextChunker {
    static let defaultTargetLength = 300
    static let defaultMaximumLength = 600

    static func chunk(
        _ text: String,
        targetLength: Int = defaultTargetLength,
        maximumLength: Int = defaultMaximumLength
    ) -> [String] {
        guard !text.isEmpty else { return [] }
        precondition(targetLength > 0 && maximumLength >= targetLength)

        var chunks: [String] = []
        let paragraphs = text.components(separatedBy: "\n\n")

        for paragraph in paragraphs {
            let para = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !para.isEmpty else { continue }

            var current = ""
            for sentence in sentences(in: para) {
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
