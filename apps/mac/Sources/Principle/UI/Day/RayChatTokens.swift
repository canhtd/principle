import DesignSystem
import SwiftUI

/// The Ask Ray pane's own measurements.
///
/// Everything here comes from Eden's measured chat pane — `board-chat-pane.json`,
/// `chat-message.json` and `chat-cc.css`, in the `.ai-sidepeek-chat` variant that
/// applies to a pane this narrow — by way of the frozen prototype
/// (`docs/design/proto-day-A.html`, decision 12).
///
/// It exists because `DesignSystem` does not carry them. Eden's chat is warmer
/// than the rest of Eden: its inks are brown-blacks and its overlays are a warm
/// grey rather than pure black, and a token file that spelled those as
/// `EdenColor.n500` would be quietly wrong. Anything that *does* have a token —
/// the accent, the card white, the black overlays, radii `md` and `lg` — is
/// taken from `DesignSystem` at the call site rather than copied here.
enum RayChat {
    // MARK: Inks (measured; Eden's chat runs warmer than `EdenColor`'s neutrals)

    /// Body copy in a turn, and a card's title. Warmer than `EdenColor.textPrimary`.
    static let ink = EdenColor.hex(0x3F342C)
    /// A card's excerpt, and the composer's dictate glyph.
    static let inkSoft = EdenColor.hex(0x7A6F64)
    /// Timestamps, the day divider, a card's label.
    static let muted = EdenColor.hex(0x9A8F84)
    /// The pane title. Measured as `#a3a3a3` — near `EdenColor.n400` (`#a1a1a1`)
    /// but not it, and the prototype calls that out, so it stays measured.
    static let title = EdenColor.hex(0xA3A3A3)

    /// Eden's chat overlays are this brown at a low alpha, never black.
    static func warm(_ percent: Double) -> Color {
        Color(.sRGB, red: 70 / 255, green: 60 / 255, blue: 45 / 255, opacity: percent / 100)
    }

    // MARK: The pane

    /// `.rayhead` — h62, `padding: 20px 16px 10px`.
    static let headerHeight: CGFloat = 62
    static let headerPaddingTop: CGFloat = 20
    static let headerPaddingBottom: CGFloat = 10
    static let headerPaddingH: CGFloat = 16
    /// `.ccbtn` — a 28 pt circle around a 16 pt glyph.
    static let iconButton: CGFloat = 28
    static let iconGlyph: CGFloat = 16

    // MARK: A turn

    /// `.ccpad` — the padding around every message. *This* is the rhythm: 14 top
    /// and 14 bottom is the 28 pt between two turns, so turns carry no spacing
    /// of their own.
    static let messagePaddingV: CGFloat = 14
    static let messagePaddingH: CGFloat = 18
    /// `.msg` — no turn, either side, spans the whole pane.
    static let messageMaxWidth: CGFloat = 0.95
    /// `.msg .parts` gap.
    static let partGap: CGFloat = 8

    /// `.msg.u .parts` — the user's bubble. Radius is `EdenRadius.lg`.
    static let bubblePaddingV: CGFloat = 10
    static let bubblePaddingH: CGFloat = 15

    /// `.cc-md`, side-peek: 14 px on a 1.65 line.
    static let bodySize: CGFloat = 14
    static let bodyLineHeight: CGFloat = 1.65

    /// `.ccday` — the date a run of messages belongs to.
    static let dayDividerSize: CGFloat = 11
    static let dayDividerGap: CGFloat = 12

    // MARK: The card inside an assistant turn (`.pcard.cc`)

    static let cardPaddingV: CGFloat = 14
    static let cardPaddingTrailing: CGFloat = 16
    /// 19, not 16: the 3 pt accent stroke sits inside the radius, so the text
    /// keeps a 16 pt gap to it.
    static let cardPaddingLeading: CGFloat = 19
    static let cardStroke: CGFloat = 3
    static let cardLabelSize: CGFloat = 11
    static let cardLabelTracking: CGFloat = 0.06
    static let cardTitleSize: CGFloat = 15
    static let cardTitleLineHeight: CGFloat = 1.5
    static let favoriteButton: CGFloat = 22

    // MARK: The composer (`.ccform`, `.ccpill`, `.ccrow`)

    /// `width: calc(100% - 28px)` — 14 a side.
    static let composerInset: CGFloat = 14
    static let composerBottom: CGFloat = 20
    static let pillRadius: CGFloat = 22
    static let pillRowPaddingTop: CGFloat = 14
    static let pillRowPaddingH: CGFloat = 12
    static let pillRowPaddingBottom: CGFloat = 12
    static let pillRowGap: CGFloat = 6
    static let composerTextSize: CGFloat = 15
    static let composerTextLineHeight: CGFloat = 1.35
    static let composerTextMinHeight: CGFloat = 36
    static let sendButton: CGFloat = 28
}
