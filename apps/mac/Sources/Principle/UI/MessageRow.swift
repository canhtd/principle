import PrincipleCore
import SwiftUI

/// One line of the conversation. The speaker is a label rather than a coloured
/// bubble: the answers are long-form and read better as a document.
///
/// Extracted from `ChatView` when the cards grew affordances of their own (U6).
struct MessageRow: View {
    let message: ChatMessage
    /// The principles this message cited, already resolved against the corpus.
    var cards: [PrincipleCardModel] = []
    var isFavorite: (PrincipleRecord) -> Bool = { _ in false }
    var toggleFavorite: (PrincipleRecord) -> Void = { _ in }
    var chapterContext: (PrincipleRecord) -> ChapterContext? = { _ in nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "You" : "Ray")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            // Cards before prose: the diagnosis and the principles are what the
            // answer was decided by, so they are what the reader meets first.
            // While the answer streams there is no trailer yet and no cards —
            // they arrive above the text when the turn lands.
            PrincipleCardList(
                diagnosis: message.diagnosis?.cleaned,
                cards: cards,
                isFavorite: isFavorite,
                toggleFavorite: toggleFavorite,
                chapterContext: chapterContext
            )
            .padding(.bottom, hasCards ? Spacing.cardListGap : 0)
            if !message.text.isEmpty {
                // The engine answers in Markdown; showing it verbatim leaves
                // `**bold**` and one wall of text on screen.
                MarkdownText(text: message.text)
            }
        }
    }

    private var hasCards: Bool { message.diagnosis?.cleaned != nil || !cards.isEmpty }
}

#Preview {
    MessageRow(
        message: ChatMessage(role: .assistant, text: "[PREVIEW] Đây là đoạn trả lời của Ray.")
    )
    .padding()
    .frame(width: 520)
}
