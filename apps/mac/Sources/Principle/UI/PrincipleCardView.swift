import PrincipleCore
import SwiftUI

/// One principle, drawn the way `references/artifact-spec.md` asks for it: a
/// black card, a red label, the title verbatim from the book, and two lines of
/// what is behind it.
///
/// The card is a door, not the room. Everything that used to sit under a
/// disclosure — the full body, the bridge into this case, ♥, the chapter — now
/// lives in ``PrincipleDetailView``, because three cards half-opened in a
/// transcript is the wall of text the stack was meant to replace.
struct PrincipleCardView: View {
    let card: PrincipleCardModel
    /// Opens the detail sheet. The whole card is the target.
    var open: () -> Void = {}

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 0) {
                label
                title
                excerpt
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.cardPadding)
            .background(Palette.card, in: RoundedRectangle(cornerRadius: Palette.cardRadius))
            .overlay {
                // Keeps the card an object rather than a hole when the window is
                // itself dark.
                RoundedRectangle(cornerRadius: Palette.cardRadius)
                    .strokeBorder(Palette.cardHairline, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: Palette.cardRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(card.detailLabel). \(card.title)")
        .accessibilityHint("Opens the principle in full")
    }

    // MARK: - Face

    /// Which half of the book, and nothing more — the title below is the
    /// headline now, so the label is back to being a category.
    private var label: some View {
        HStack(alignment: .top, spacing: Spacing.cardRow) {
            Rectangle()
                .fill(Palette.red)
                .frame(width: 3)
            Text(card.partLabel)
                .font(Typography.label)
                .tracking(Typography.labelTracking)
                .lineSpacing(Typography.labelLineSpacing)
                .foregroundStyle(Palette.red)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var title: some View {
        Text(card.title)
            .font(Typography.cardTitle)
            .tracking(Typography.cardTitleTracking)
            // Vietnamese marks stack above and below; 1.35 is the floor.
            .lineSpacing(Typography.cardTitleLineSpacing)
            .foregroundStyle(Palette.cardTitle)
            .multilineTextAlignment(.leading)
            // A principle that runs past three lines is quoted, not printed:
            // the sheet has the rest.
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Spacing.cardRow)
    }

    /// Fixed at two lines, always cut: the point is that there is more, not what
    /// the more happens to be.
    @ViewBuilder
    private var excerpt: some View {
        if let excerpt = card.excerpt {
            Text(excerpt)
                .vietnameseBody()
                .foregroundStyle(Palette.cardExcerpt)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Spacing.cardQuoteTop)
        }
    }
}
