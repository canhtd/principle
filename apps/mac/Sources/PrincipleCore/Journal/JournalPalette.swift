import Foundation

/// Which colour a category wears.
///
/// A *key*, never a colour value — the palette itself belongs to the theme (see
/// ``JournalCategory``), and a stored `#3B82F6` would freeze today's theme into
/// the repo files for good. Keys are handed out in order and then wrap, so the
/// first few categories of a fresh journal are visibly different from each other
/// without anyone being asked to pick.
public enum JournalPalette {
    /// The order colours are handed out in, and the order the "Change color"
    /// swatches are drawn in.
    public static let colorKeys = ["olive", "blueberry", "clay", "plum", "sand", "slate"]

    /// What a category falls back to when its key is one this build does not
    /// know — a hand-edited file, or a key from a later palette.
    public static let fallbackColorKey = "olive"

    public static func nextColorKey(after existing: [JournalCategory]) -> String {
        colorKeys[existing.count % colorKeys.count]
    }
}
