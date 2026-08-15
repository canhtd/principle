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

    /// Reading width: past ~70 characters the eye loses the next line.
    static let readingWidth: CGFloat = 640
}

extension View {
    /// Body copy with the leading Vietnamese needs.
    func vietnameseBody() -> some View {
        font(Typography.body).lineSpacing(Typography.bodyLineSpacing)
    }
}
