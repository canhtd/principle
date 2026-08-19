import DesignSystem
import PrincipleCore
import SwiftUI

/// A principle the answer was decided by, riding inside the assistant's turn and
/// above its prose (decision 12).
///
/// The same idea as ``PrincipleCardSmall`` in column 1 — an accent stroke inside
/// the radius, an uppercase corpus label, the title, the bookmark — but on
/// Eden's *in-message* card tokens (`.cc-format-pick`) rather than the panel's:
/// a warm tint instead of white, no shadow, and room for two lines of the book.
struct AskRayCard: View {
    let card: PrincipleCardModel
    let isFavorite: Bool
    let toggleFavorite: () -> Void
    /// Opens the excerpt beside the card, the way column 1's does (decision 5).
    let open: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: RayChat.partGap) {
                label
                favorite
            }
            title
            excerpt
        }
        .padding(.vertical, RayChat.cardPaddingV)
        .padding(.leading, RayChat.cardPaddingLeading)
        .padding(.trailing, RayChat.cardPaddingTrailing)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RayChat.warm(isHovering ? 3 : 1.9))
        .overlay(alignment: .leading) { EdenColor.primary.frame(width: RayChat.cardStroke) }
        .clipShape(.rect(cornerRadius: EdenRadius.md, style: .continuous))
        .edenBorder(RayChat.warm(isHovering ? 16 : 8), radius: EdenRadius.md)
        .contentShape(.rect)
        .onHover { isHovering = $0 }
        .onTapGesture(perform: open)
    }

    /// `LIFE PRINCIPLE 5.6`. Lighter and wider-set than the panel card's label —
    /// inside a turn it is a caption, not a heading.
    private var label: some View {
        Text(PrincipleLabel.text(for: card.record))
            .font(EdenFont.ui(RayChat.cardLabelSize, .medium))
            .tracking(RayChat.cardLabelSize * RayChat.cardLabelTracking)
            .foregroundStyle(RayChat.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var favorite: some View {
        Button(action: toggleFavorite) {
            Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                .font(EdenFont.ui(12))
                .foregroundStyle(isFavorite ? EdenColor.primary : RayChat.muted)
                .frame(width: RayChat.favoriteButton, height: RayChat.favoriteButton)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusEffectDisabled()
        .help(isFavorite ? "Remove from favourites" : "Add to favourites")
        .offset(x: 3, y: -3)
    }

    private var title: some View {
        Text(card.title)
            .font(EdenFont.ui(RayChat.cardTitleSize, .medium))
            .lineSpacing(RayChat.cardTitleSize * (RayChat.cardTitleLineHeight - 1))
            .foregroundStyle(RayChat.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    /// Two lines of the book and no more — the whole passage belongs in the
    /// excerpt popover, not in the middle of an answer.
    @ViewBuilder
    private var excerpt: some View {
        if let text = card.excerpt, !text.isEmpty {
            Text(text)
                .font(EdenFont.ui(RayChat.bodySize))
                .lineSpacing(RayChat.bodySize * (RayChat.bodyLineHeight - 1))
                .foregroundStyle(RayChat.inkSoft)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)
        }
    }
}
