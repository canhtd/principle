import Foundation

/// What column 3's "Review your day" reads and writes: one Dot per Category on
/// the day that is on screen.
///
/// Every command here writes and re-reads through ``JournalModel/write(_:)``,
/// so a Dot that shows on the track is a Dot that is on disk — and a write that
/// did not land says so in the same banner a task edit does.
extension JournalModel {
    /// The tracks the pane draws: the categories column 1 is showing, in the
    /// order the rest of the app lists them.
    ///
    /// The filter is deliberate — column 1's ticks are one filter over the whole
    /// screen (decision 3), and a track for a category Danny has just hidden
    /// would be arguing with the tick he cleared.
    public var reviewCategories: [JournalCategory] { categories.filter(isShown) }

    public func dot(for categoryID: UUID) -> JournalDot? { dots[categoryID] }

    /// Where a Category's Dot stands on the day on screen, or `nil` for unset.
    public func dotHeight(for categoryID: UUID) -> Int? { dots[categoryID]?.height }

    /// Places or moves a Dot. A drag crosses the same step many times, so a
    /// height that is already the one on file writes nothing: the file records
    /// judgements, not pointer movement.
    public func setDot(_ height: Int, for categoryID: UUID) {
        let wanted = JournalDot.clamp(height)
        guard dots[categoryID]?.height != wanted else { return }
        let day = day
        write { try $0.setDot(wanted, categoryID: categoryID, on: day) }
    }

    /// Clicking a Dot on the step it already stands on takes the judgement back.
    public func clearDot(for categoryID: UUID) {
        guard dots[categoryID] != nil else { return }
        let day = day
        write { try $0.clearDot(categoryID: categoryID, on: day) }
    }
}
