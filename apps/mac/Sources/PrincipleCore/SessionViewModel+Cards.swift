import Foundation

extension SessionViewModel {
    /// The cards to draw under one answer: the ids the message cited, resolved
    /// against the local corpus, each carrying its verbatim quote and the
    /// engine's bridge into this case (KTD3).
    ///
    /// An id the corpus does not know produces no card — the app never invents
    /// a citation the engine did not make (AE2).
    public func cards(for message: ChatMessage) -> [PrincipleCardModel] {
        PrincipleCardModel.cards(for: message.principles, corpus: corpus)
    }
}
