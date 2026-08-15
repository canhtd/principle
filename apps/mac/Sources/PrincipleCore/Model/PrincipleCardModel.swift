import Foundation

/// Which half of the book a principle comes from.
///
/// The corpus id is the reliable signal (`life:5.6`, `work:3.4`); the
/// Vietnamese `part` string is only the fallback, for a record that carries no
/// prefixed id.
public enum PrinciplePart: String, Equatable, Sendable {
    case life
    case work
    /// Neither half could be established — the card prints no half, rather than
    /// guessing one (AE2).
    case unknown

    /// The red label at the top of a card. Chrome, so English, while everything
    /// coming out of the corpus stays Vietnamese.
    public var label: String {
        switch self {
        case .life: "LIFE PRINCIPLE"
        case .work: "WORK PRINCIPLE"
        case .unknown: "PRINCIPLE"
        }
    }

    public init(record: PrincipleRecord) {
        // `split` hands back the whole id when there is no colon, which simply
        // matches neither case and falls through to the part text.
        switch record.id.split(separator: ":", maxSplits: 1).first?.lowercased() {
        case "life": self = .life
        case "work": self = .work
        default:
            let part = record.part.lowercased()
            if part.contains("làm việc") {
                self = .work
            } else if part.contains("sống") {
                self = .life
            } else {
                self = .unknown
            }
        }
    }
}

/// One principle card, ready to draw: what the corpus says, plus the one thing
/// only the engine can say — where this principle cuts into *this* case.
///
/// Pure and view-free on purpose. The card carries a lot of small decisions
/// (which label, is there a quote at all, is there a bridge) and they are worth
/// testing without a window.
public struct PrincipleCardModel: Identifiable, Equatable, Sendable {
    /// How many cards one answer may show, per the artifact spec.
    public static let maxCards = 3

    /// The corpus record, verbatim. Kept whole so the card's affordances —
    /// favourite, chapter context — still speak in records.
    public let record: PrincipleRecord
    public let part: PrinciplePart
    /// One or two sentences bridging the principle to the case, or `nil` when
    /// the engine cited an id without one (the legacy trailer shape).
    public let apply: String?

    public var id: String { record.id }
    public var title: String { record.title }

    /// `LIFE PRINCIPLE · 4.3e` — the red label above the title.
    public var label: String {
        let num = record.num.trimmingCharacters(in: .whitespacesAndNewlines)
        return num.isEmpty ? part.label : "\(part.label) · \(num)"
    }

    /// ≤40 words, verbatim from the book. `nil` for a heading-only record: the
    /// heading *is* the principle, and there is nothing to quote (AE3).
    public var quote: String? { record.quote }

    public var hasQuote: Bool { quote != nil }
    public var hasApply: Bool { apply != nil }
    /// Nothing behind the disclosure means the card does not offer to open.
    public var isExpandable: Bool { hasQuote || hasApply }

    public init(record: PrincipleRecord, apply: String? = nil) {
        self.record = record
        self.part = PrinciplePart(record: record)
        let trimmed = apply?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apply = (trimmed?.isEmpty ?? true) ? nil : trimmed
    }
}

extension PrincipleCardModel {
    /// The cards for one cited answer, in citation order and capped at three.
    ///
    /// An id the corpus does not know produces no card (AE2); the cap is
    /// applied after that, so three resolvable citations always draw three.
    public static func cards(
        for refs: [PrincipleRef],
        corpus: CorpusStore,
        limit: Int = maxCards
    ) -> [PrincipleCardModel] {
        let resolved = refs.compactMap { ref -> PrincipleCardModel? in
            guard let record = corpus.principle(id: ref.id) else { return nil }
            return PrincipleCardModel(record: record, apply: ref.displayApply)
        }
        return Array(resolved.prefix(max(0, limit)))
    }

    /// Cards for records that come with no case attached — the Favorites
    /// section. No bridge text, and no cap: this is a list, not an answer.
    public static func cards(for records: [PrincipleRecord]) -> [PrincipleCardModel] {
        records.map { PrincipleCardModel(record: $0) }
    }
}
