import DesignSystem
import PrincipleCore
import SwiftUI

/// One turn of the conversation, in Eden's two shapes: the question as a bubble
/// that fits its text and is pushed right, the answer as bare prose down the
/// left of the pane.
///
/// Neither shape carries spacing. The 14 pt of padding above and below is the
/// whole rhythm — two turns meeting make Eden's 28 pt gap, and a turn dropped
/// from the thread takes its gap with it.
struct AskRayTurn: View {
    let message: ChatMessage
    let cards: [PrincipleCardModel]
    let favorites: FavoritesModel
    @Bindable var ui: DayShellState
    /// The pane's width, which is what "95% of it" is measured against.
    let width: CGFloat

    @State private var isHovering = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 0) {
            timestamp
            parts
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .padding(.vertical, RayChat.messagePaddingV)
        .padding(.horizontal, RayChat.messagePaddingH)
        .onHover { isHovering = $0 }
    }

    /// Above the turn and out of the flow, so a message does not change height
    /// when the pointer crosses it.
    private var timestamp: some View {
        Text(message.sentAt.formatted(date: .omitted, time: .shortened))
            .font(EdenFont.ui(RayChat.dayDividerSize))
            .foregroundStyle(RayChat.muted)
            .opacity(isHovering ? 1 : 0)
            .animation(.easeOut(duration: 0.14), value: isHovering)
            .frame(height: 0, alignment: .bottom)
            .offset(y: -4)
            .allowsHitTesting(false)
    }

    private var parts: some View {
        VStack(alignment: .leading, spacing: RayChat.partGap) {
            // Cards before prose: the principles are what the answer was decided
            // by, so they are what the reader meets first.
            ForEach(cards) { card in
                AskRayCard(
                    card: card,
                    isFavorite: favorites.isFavorite(card.id),
                    toggleFavorite: { favorites.toggle(card.id) },
                    open: { ui.openPrincipleID = card.id }
                )
                .principleExcerpt(record: card.record, favorites: favorites, ui: ui)
            }
            if let diagnosis = message.diagnosis?.cleaned {
                RayDiagnosis(diagnosis: diagnosis)
            }
            if !message.text.isEmpty {
                // A question is typed by a person and is not Markdown, so it is
                // set as plain text — which is also what lets the bubble hug it
                // rather than stretch to the pane (`width: fit-content`).
                if isUser {
                    Text(message.text)
                        .font(EdenFont.ui(RayChat.bodySize))
                        .lineSpacing(RayChat.bodySize * (RayChat.bodyLineHeight - 1))
                        .foregroundStyle(RayChat.ink)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    prose(message.text)
                }
            }
        }
        .modifier(BubbleShape(isUser: isUser))
        .frame(maxWidth: maxWidth, alignment: .leading)
    }

    /// The engine answers in Markdown; showing it verbatim leaves `**bold**` and
    /// one wall of text on screen.
    private func prose(_ text: String) -> some View {
        MarkdownText(text: text, style: .askRay)
    }

    /// A turn never spans the whole pane — 95% of it, so the edge of the thread
    /// stays visible as an edge.
    private var maxWidth: CGFloat {
        let content = max(0, width - RayChat.messagePaddingH * 2)
        return content * RayChat.messageMaxWidth
    }
}

/// What kind of case this is, when the engine named one. It sits above the
/// cards, because the cards are what the diagnosis was answered with.
///
/// The prototype has no element for it — the sample turn is card plus prose —
/// so it is set in the pane's own type rather than borrowing the reading
/// window's red label, which would be the loudest thing on the pane.
private struct RayDiagnosis: View {
    let diagnosis: Diagnosis

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !diagnosis.kind.isEmpty {
                Text(diagnosis.kind)
                    .font(EdenFont.ui(RayChat.bodySize, .medium))
                    .foregroundStyle(RayChat.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !diagnosis.why.isEmpty {
                Text(diagnosis.why)
                    .font(EdenFont.ui(RayChat.bodySize))
                    .lineSpacing(RayChat.bodySize * (RayChat.bodyLineHeight - 1))
                    .foregroundStyle(RayChat.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The question wears Eden's bubble; the answer wears nothing at all.
private struct BubbleShape: ViewModifier {
    let isUser: Bool

    func body(content: Content) -> some View {
        if isUser {
            content
                .padding(.vertical, RayChat.bubblePaddingV)
                .padding(.horizontal, RayChat.bubblePaddingH)
                .background(RayChat.warm(3), in: .rect(cornerRadius: EdenRadius.lg, style: .continuous))
                .edenBorder(RayChat.warm(10), radius: EdenRadius.lg)
                .shadow(color: EdenColor.hex(0x0F172A).opacity(0.08), radius: 12, y: 10)
                // Fits its text rather than filling the pane, which is what
                // makes a short question read as an aside.
                .fixedSize(horizontal: false, vertical: true)
        } else {
            content
        }
    }
}
