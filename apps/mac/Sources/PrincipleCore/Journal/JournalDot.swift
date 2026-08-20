import Foundation

/// One Category's Dot on one day: Danny's own judgement of how that kind of
/// activity went, on a height of 1 (low) to 10 (high).
///
/// There is no zero and no default. A Category he has nothing to say about that
/// day simply has no Dot — blank is not a bad day (ADR 0001), so "unset" is the
/// absence of one of these rather than a value inside it.
///
/// The Category's name and colour are copied in rather than looked up later: a
/// Dot outlives the Category it was set for, and a chart that lost its colours
/// the day a Category was deleted would lose its past with them.
public struct JournalDot: Equatable, Sendable {
    /// The ten steps a Dot can stand on.
    public static let heights = 1...10
    /// Where an unset Dot rests on the track. A rendering decision, never a
    /// stored one: nothing is written for a Category without a Dot.
    public static let restingHeight = 5

    public let day: JournalDay
    public let categoryID: UUID
    public let height: Int
    /// What the Category was called when the Dot was set.
    public let categoryName: String
    /// The colour key it wore then — a key, never a colour value, for the same
    /// reason ``JournalCategory`` keeps one.
    public let colorKey: String

    public init(day: JournalDay, categoryID: UUID, height: Int, categoryName: String, colorKey: String) {
        self.day = day
        self.categoryID = categoryID
        self.height = Self.clamp(height)
        self.categoryName = categoryName
        self.colorKey = colorKey
    }

    /// Pulls a height onto the track. A hand-edited `14` is a 10, not a reason
    /// to drop the line: the judgement it records is still readable.
    public static func clamp(_ height: Int) -> Int {
        min(heights.upperBound, max(heights.lowerBound, height))
    }
}
