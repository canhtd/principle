import Foundation

/// An answer split into what the reader sees and what the app draws as cards.
public struct ParsedAnswer: Equatable, Sendable {
    /// The answer with the trailer removed. Identical to the input when there
    /// was no trailer to remove.
    public let text: String
    /// Corpus ids, in the order the answer cited them.
    public let principleIDs: [String]

    public init(text: String, principleIDs: [String]) {
        self.text = text
        self.principleIDs = principleIDs
    }
}

/// Reads the `PRINCIPLES_JSON` trailer (KTD3).
///
/// Exactly one line at the very end of an answer:
///
///     PRINCIPLES_JSON: {"ids":["life:5.6","life:1.8"]}
///
/// Keyed by corpus `id`, never by `num` — "2.1" exists in both parts of the
/// book. Anything else (no trailer, malformed JSON, the marker somewhere other
/// than the last line) leaves the text exactly as it arrived and produces no
/// cards: the app never invents a citation the engine did not make (AE2).
public enum TrailerParser {
    public static let marker = "PRINCIPLES_JSON:"

    private struct Trailer: Decodable {
        let ids: [String]
    }

    public static func parse(_ answer: String) -> ParsedAnswer {
        var lines = answer.components(separatedBy: .newlines)
        // Trailing blank lines are formatting, not content.
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        guard let candidate = lines.last, let ids = ids(inTrailerLine: candidate) else {
            return ParsedAnswer(text: answer, principleIDs: [])
        }
        lines.removeLast()
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedAnswer(text: text, principleIDs: ids)
    }

    /// What to show while the answer is still arriving. Once the marker appears
    /// on the last line its JSON is still streaming in character by character,
    /// and machine syntax must never flash up in the transcript.
    public static func visibleText(streaming partial: String) -> String {
        let lineStart = partial.range(of: "\n", options: .backwards)?.upperBound ?? partial.startIndex
        guard partial[lineStart...].trimmingCharacters(in: .whitespaces).hasPrefix(marker) else {
            return partial
        }
        return String(partial[..<lineStart]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The ids on one line, or `nil` when the line is not a trailer the app can
    /// trust. An empty `ids` array is trusted — the engine said "nothing to
    /// cite", which is different from saying nothing at all.
    private static func ids(inTrailerLine line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(marker) else { return nil }
        let json = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        guard let trailer = try? JSONDecoder().decode(Trailer.self, from: Data(json.utf8)) else {
            return nil
        }
        var seen = Set<String>()
        return trailer.ids
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
