import Foundation

extension SessionViewModel {
    /// The cards to draw under one answer: the ids the message cited, resolved
    /// against the local corpus, each carrying its verbatim quote and the
    /// engine's bridge into this case (KTD3).
    ///
    /// Kept next to `principles(for:)` rather than replacing it — the plain
    /// record list is still what the Favorites section and the tests want.
    public func cards(for message: ChatMessage) -> [PrincipleCardModel] {
        PrincipleCardModel.cards(for: message.principles, corpus: corpus)
    }
}
