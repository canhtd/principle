import SwiftUI

/// Type scale for the chat, following `references/artifact-spec.md`.
///
/// System fonts only — they are the ones with a complete Vietnamese diacritic
/// set, and there is no webfont to load in a native app anyway. The leading
/// matters more than the size here: Vietnamese marks sit above *and* below the
/// line, so English-ish line-height (1.3–1.4) makes them collide. SwiftUI takes
/// extra spacing rather than a multiplier, hence `size * (ratio - 1)`.
enum Typography {
    static let bodySize: CGFloat = 15
    static let body = Font.system(size: bodySize)
    /// line-height 1.7 — long Vietnamese prose.
    static let bodyLineSpacing = bodySize * 0.7

    static let titleSize: CGFloat = 17
    static let title = Font.system(size: titleSize, weight: .semibold)
    /// line-height 1.35 — headings.
    static let titleLineSpacing = titleSize * 0.35

    static let captionSize: CGFloat = 12
    static let caption = Font.system(size: captionSize)
    /// line-height 1.4 — labels and captions, never tighter.
    static let captionLineSpacing = captionSize * 0.4

    /// Inline code inside an answer — `4.3e`, a file path, a command.
    static let mono = Font.system(size: bodySize - 1, design: .monospaced)

    /// The one thing the eye is meant to catch first on a card, so it is the
    /// only place besides the red label that is allowed weight 600.
    static let cardTitleSize: CGFloat = 20
    static let cardTitle = Font.system(size: cardTitleSize, weight: .semibold)
    static let cardTitleLineSpacing = cardTitleSize * 0.35
    /// System faces are spaced for body copy; left alone at 20pt a heading
    /// reads loose.
    static let cardTitleTracking: CGFloat = -0.2

    /// `LIFE PRINCIPLE · 4.3e` and the other small caps labels.
    static let labelSize: CGFloat = 11
    static let label = Font.system(size: labelSize, weight: .semibold)
    static let labelLineSpacing = labelSize * 0.4
    /// 0.08em — small caps need the extra air to stay readable.
    static let labelTracking = labelSize * 0.08

    /// The quieter label inside a card ("APPLIED TO THIS CASE").
    static let smallLabelSize: CGFloat = 10
    static let smallLabel = Font.system(size: smallLabelSize, weight: .semibold)
    static let smallLabelTracking = smallLabelSize * 0.08

    /// Reading width: past ~70 characters the eye loses the next line.
    static let readingWidth: CGFloat = 640
    /// Cards stop well short of the prose column: ~62 characters of Vietnamese
    /// once the card's own padding is taken off.
    static let cardWidth: CGFloat = 520
}

/// The card palette, straight from `references/artifact-spec.md`.
///
/// Fixed values rather than semantic colours: the card is a black object by
/// design — it is the contrast against the page that makes the stack readable —
/// so it keeps its own ink in both appearances.
enum Palette {
    static let red = Color(red: 0.910, green: 0.200, blue: 0.165) // #E8332A
    static let card = Color(red: 0.039, green: 0.039, blue: 0.039) // #0A0A0A
    static let cardTitle = Color.white
    static let cardQuote = Color(white: 0.604) // #9A9A9A
    static let cardApply = Color(white: 0.894) // #E4E4E4
    static let cardMuted = Color(white: 0.541) // #8A8A8A
    /// Separates the bridge from the principle, and the card from a dark page.
    static let cardHairline = Color.white.opacity(0.10)
    static let cardRadius: CGFloat = 20

    /// The diagnosis sits on a light panel so the black cards below read as a
    /// second, heavier register.
    static let diagnosisBackground = Color.primary.opacity(0.04)
    static let diagnosisRadius: CGFloat = 16
}

/// Vertical and horizontal rhythm inside a message. Derived from the type scale
/// so the spacing keeps its proportions if the body size ever moves.
enum Spacing {
    /// Between two blocks of the same answer — wide enough to read as a break,
    /// tighter than the gap between two messages.
    static let block = Typography.bodySize * 0.7
    /// Extra air above a heading that follows other content.
    static let headingTop = Typography.bodySize * 0.4
    /// Between two lines of the same list — tighter, so the list reads as one
    /// thing rather than as loose paragraphs.
    static let listItem = Typography.bodySize * 0.3
    /// Gutter a list item is pushed in by.
    static let listIndent = Typography.bodySize * 0.5
    /// Between a bullet and its text.
    static let listMarkerGap = Typography.bodySize * 0.45

    /// Inside a principle card. The spec's ≥480px padding, since a Mac window
    /// is never the 380px phone the artifact was drawn for.
    static let cardPadding: CGFloat = 20
    /// Between two cards in a stack.
    static let cardGap: CGFloat = 12
}

extension View {
    /// Body copy with the leading Vietnamese needs.
    func vietnameseBody() -> some View {
        font(Typography.body).lineSpacing(Typography.bodyLineSpacing)
    }
}
