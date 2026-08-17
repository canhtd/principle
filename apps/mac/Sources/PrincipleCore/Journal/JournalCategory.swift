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

    public init(id: UUID = UUID(), name: String, colorKey: String) {
        self.id = id
        self.name = name
        self.colorKey = colorKey
    }
}
