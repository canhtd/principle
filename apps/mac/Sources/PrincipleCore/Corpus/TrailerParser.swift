import Foundation

/// An answer split into what the reader sees and what the app draws as cards.
public struct ParsedAnswer: Equatable, Sendable {
    /// The answer with the trailer removed. Identical to the input when there
    /// was no trailer to remove.
    public let text: String
    /// What kind of case the engine says this is, when it said so.
    public let diagnosis: Diagnosis?
    /// Cited principles, in the order the answer cited them, each with the
    /// bridge the engine wrote for this case.
    public let principles: [PrincipleRef]

    /// Just the cited ids, for the lookups that need nothing else.
    public var principleIDs: [String] { principles.map(\.id) }

    public init(text: String, diagnosis: Diagnosis? = nil, principles: [PrincipleRef] = []) {
        self.text = text
        self.diagnosis = diagnosis
        self.principles = principles
    }

    /// Ids with no bridge text — the legacy trailer shape.
    public init(text: String, principleIDs: [String]) {
        self.init(text: text, principles: principleIDs.map { PrincipleRef(id: $0) })
    }
}

/// Reads the `PRINCIPLES_JSON` trailer (KTD3).
///
/// Exactly one line at the very end of an answer:
///
///     PRINCIPLES_JSON: {"diagnosis":{"kind":"…","why":"…"},
///                       "principles":[{"id":"life:5.6","apply":"…"}]}
///
/// The older `{"ids":["life:5.6"]}` shape is still read, so sessions filed
/// before the rich trailer keep rendering their cards.
///
/// Keyed by corpus `id`, never by `num` — "2.1" exists in both parts of the
/// book. Anything else (no trailer, malformed JSON, the marker somewhere other
/// than the last line) leaves the text exactly as it arrived and produces no
/// cards: the app never invents a citation the engine did not make (AE2).
public enum TrailerParser {
    public static let marker = "PRINCIPLES_JSON:"

    private struct Trailer: Decodable {
        let diagnosis: Diagnosis?
        let principles: [PrincipleRef]?
        /// Legacy shape.
        let ids: [String]?
    }

    public static func parse(_ answer: String) -> ParsedAnswer {
        var lines = answer.components(separatedBy: .newlines)
        // Trailing blank lines are formatting, not content.
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeLast()
        }
        guard let candidate = lines.last, let trailer = trailer(inLine: candidate) else {
            return ParsedAnswer(text: answer)
        }
        lines.removeLast()
        let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedAnswer(
            text: text,
            diagnosis: trailer.diagnosis?.cleaned,
            principles: references(in: trailer)
        )
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

    /// The trailer on one line, or `nil` when the line is not one the app can
    /// trust. A trailer that cites nothing is trusted — the engine said "nothing
    /// to cite", which is different from saying nothing at all.
    private static func trailer(inLine line: String) -> Trailer? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix(marker) else { return nil }
        let json = trimmed.dropFirst(marker.count).trimmingCharacters(in: .whitespaces)
        return try? JSONDecoder().decode(Trailer.self, from: Data(json.utf8))
    }

    /// The rich shape wins when both are present; ids without a bridge are still
    /// cards, just bare ones. Duplicates collapse onto their first citation.
    private static func references(in trailer: Trailer) -> [PrincipleRef] {
        let cited = trailer.principles ?? (trailer.ids ?? []).map { PrincipleRef(id: $0) }
        var seen = Set<String>()
        return cited.compactMap { reference in
            let id = reference.id.trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty, seen.insert(id).inserted else { return nil }
            return PrincipleRef(id: id, apply: reference.apply.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
