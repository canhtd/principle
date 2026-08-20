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

    // MARK: - Evidence

    /// What Danny ticked on the day on screen, by Category — the list under the
    /// tracks.
    ///
    /// Evidence and nothing else (story 10 and 11): no height is derived from
    /// it, and ticking a task moves no Dot. An unticked row is not evidence of
    /// anything, so it is not here; a ticked row with no Category has nothing to
    /// sit under, and is not either.
    public var evidenceByCategory: [UUID: [PlannedTask]] {
        var grouped: [UUID: [PlannedTask]] = [:]
        for row in sections.all where row.isDone {
            guard let id = row.category?.id else { continue }
            grouped[id, default: []].append(row)
        }
        return grouped
    }

    /// The ticked tasks of one Category on the day on screen, in the order the
    /// day draws them.
    public func evidence(for categoryID: UUID) -> [PlannedTask] {
        evidenceByCategory[categoryID] ?? []
    }

    // MARK: - The Bar and the Day note

    /// The sentence a Category is measured against, or `nil` where none was
    /// written — the track shows one thing when there is a bar and another when
    /// there is not.
    public func bar(for categoryID: UUID) -> String? { category(id: categoryID)?.bar }

    /// Writes a Category's Bar. An empty sentence takes it back; a sentence that
    /// is already the one on file writes nothing, so closing the field without
    /// changing anything leaves the file alone.
    public func setBar(_ text: String, for categoryID: UUID) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (bar(for: categoryID) ?? "") else { return }
        write { try $0.setBar(trimmed, categoryID: categoryID) }
    }

    /// Writes the Day note as it is typed — the same bargain the Dots make:
    /// there is no Save, so what is on screen is what is on disk. Text that has
    /// not changed writes nothing, so a field that only gained focus leaves no
    /// line behind.
    public func setDayNote(_ text: String) { setDayNote(text, on: day) }

    /// The same write, said about a named day: a note typed a moment before ‹ was
    /// pressed belongs to the day it was written about, not to the one that
    /// arrived while the field was settling.
    public func setDayNote(_ text: String, on day: Date) {
        let known = calendar.isDate(day, inSameDayAs: self.day) ? dayNote : store.dayNote(on: day)
        let isBlank = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        // Blank on a day that never had a note is not a change; without this a
        // field being tabbed through would file a deletion every time.
        guard text != (known ?? ""), !(isBlank && known == nil) else { return }
        write { try $0.setDayNote(text, on: day) }
    }
}
