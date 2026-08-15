import Foundation

/// The book's lettered sub-points, put back on their own lines.
///
/// A number of corpus records run their sub-points together: the body arrives
/// as `a. … go nowhere.b. … underrated.c. …`, one unbroken paragraph, because
/// the break was lost on the way out of the source. Read at full length that is
/// a wall, so the markers get a newline in front of them.
///
/// Nothing is rewritten — only the whitespace between the words changes (AE2).
/// A marker counts only when it continues the alphabet from `a.`, and only when
/// at least two of them line up: one stray `a.` inside Vietnamese prose is not a
/// list, and a wrong break would be a change to the book's text.
public enum PrincipleBodyText {
    /// Sentence punctuation a sub-point may be glued to the back of.
    private static let enders: Set<Character> = [".", "?", "!", ":", ";", "”", "’", "\"", "'", ")"]

    public static func subPointsOnOwnLines(_ text: String) -> String {
        let characters = Array(text)
        let markers = Set(markerIndices(in: characters))
        guard markers.count >= 2 else { return text }

        var out = ""
        out.reserveCapacity(characters.count + markers.count)
        for (index, character) in characters.enumerated() {
            if markers.contains(index) {
                while let last = out.last, last == " " || last == "\t" { out.removeLast() }
                if !out.isEmpty, out.last != "\n" { out.append("\n") }
            }
            out.append(character)
        }
        return out
    }

    /// Where each accepted marker starts, walking the alphabet from `a.`. A
    /// letter that does not continue the run is left alone, so `b.` on its own
    /// stays inside the sentence it was written in.
    private static func markerIndices(in characters: [Character]) -> [Int] {
        var indices: [Int] = []
        var expected: Character? = "a"
        for index in characters.indices {
            guard let letter = expected, characters[index] == letter else { continue }
            guard isMarker(characters, at: index) else { continue }
            indices.append(index)
            expected = successor(of: letter)
        }
        return indices
    }

    /// A marker is a lone letter, a full stop, then a space or a word — and it
    /// stands after a break in the text rather than inside a word, so `dữ liệu
    /// a.` opens a sub-point while `data.` does not.
    private static func isMarker(_ characters: [Character], at index: Int) -> Bool {
        guard index + 1 < characters.count, characters[index + 1] == "." else { return false }
        let after = index + 2
        if after < characters.count, !characters[after].isWhitespace, !characters[after].isLetter {
            return false
        }
        guard index > 0 else { return true }
        let before = characters[index - 1]
        return before.isWhitespace || enders.contains(before)
    }

    private static func successor(of letter: Character) -> Character? {
        guard let ascii = letter.asciiValue, ascii < UInt8(ascii: "z") else { return nil }
        return Character(UnicodeScalar(ascii + 1))
    }
}

extension PrincipleRecord {
    /// The body as the detail sheet shows it: the corpus text, with run-on
    /// sub-points broken onto their own lines. `nil` for a heading-only record —
    /// the heading *is* the principle (AE3).
    public var detailBody: String? {
        displayBody.map(PrincipleBodyText.subPointsOnOwnLines)
    }
}
