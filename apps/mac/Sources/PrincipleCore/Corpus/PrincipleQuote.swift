import Foundation

extension PrincipleRecord {
    /// How many words of the body a card shows, per the artifact spec.
    public static let quoteWordLimit = 40

    /// The short verbatim quote a card shows under the title.
    ///
    /// Cut on a word boundary and marked with `…`. The words themselves are
    /// never rewritten or summarised — a card that paraphrases the book is the
    /// one thing this app must not do (AE2). Only the whitespace between them is
    /// normalised, so a body wrapped across lines reads as one quote.
    ///
    /// `nil` for a heading-only record: that heading *is* the principle, and
    /// there is no body to quote (AE3).
    public var quote: String? {
        guard let body = displayBody else { return nil }
        let words = body.split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return nil }
        guard words.count > Self.quoteWordLimit else { return words.joined(separator: " ") }
        return words.prefix(Self.quoteWordLimit).joined(separator: " ") + "…"
    }
}

extension CorpusStore {
    /// The quote for a cited id, or `nil` when the corpus does not know the id
    /// or the record carries no body.
    public func quote(for id: String) -> String? { principle(id: id)?.quote }
}
