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

    /// Reading width: past ~70 characters the eye loses the next line.
    static let readingWidth: CGFloat = 640
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
}

extension View {
    /// Body copy with the leading Vietnamese needs.
    func vietnameseBody() -> some View {
        font(Typography.body).lineSpacing(Typography.bodyLineSpacing)
    }
}
