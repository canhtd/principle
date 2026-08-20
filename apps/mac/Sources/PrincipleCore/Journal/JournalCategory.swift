import Foundation

/// A kind of activity Danny defines himself — "Learning", "Health", "Vessa".
///
/// The category carries a colour *key*, never a colour value: the palette
/// belongs to the theme, and a stored `#3B82F6` would freeze today's theme into
/// the repo files for good.
public struct JournalCategory: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var colorKey: String
    /// The Bar: one sentence Danny wrote about what a good day for this kind of
    /// activity looks like, and what a Dot's height is judged against.
    ///
    /// Optional, and `nil` rather than `""` when he has not written one — an
    /// empty sentence is not a bar Danny can fail to meet, and the pane has a
    /// different thing to say when there is none. Honesty beats precision: a
    /// Category may live its whole life without one.
    public var bar: String?

    public init(id: UUID = UUID(), name: String, colorKey: String, bar: String? = nil) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
        self.bar = bar
    }
}
