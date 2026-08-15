import PrincipleCore
import SwiftUI

/// One line of the conversation. The speaker is a label rather than a coloured
/// bubble: the answers are long-form and read better as a document.
///
/// Extracted from `ChatView` when the cards grew affordances of their own (U6).
struct MessageRow: View {
    let message: ChatMessage
    /// The principles this message cited, already resolved against the corpus.
    let principles: [PrincipleRecord]
    var isFavorite: (PrincipleRecord) -> Bool = { _ in false }
    var toggleFavorite: (PrincipleRecord) -> Void = { _ in }
    var showChapterContext: (PrincipleRecord) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(message.role == .user ? "Anh Danny" : "Ray")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
            if !message.text.isEmpty {
                Text(message.text)
                    .vietnameseBody()
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            PrincipleCardList(
                principles: principles,
                isFavorite: isFavorite,
                toggleFavorite: toggleFavorite,
                showChapterContext: showChapterContext
            )
        }
    }
}

#Preview {
    MessageRow(
        message: ChatMessage(role: .assistant, text: "[PREVIEW] Đây là đoạn trả lời của Ray."),
        principles: []
    )
    .padding()
    .frame(width: 520)
}
