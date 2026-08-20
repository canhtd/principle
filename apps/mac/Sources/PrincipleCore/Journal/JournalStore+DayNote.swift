import Foundation

/// The Day note: one free-text note for a whole day, in `journal/notes.jsonl`
/// beside the Dots.
///
/// Its own file rather than a field on the review lines, because it belongs to
/// the day and not to any Category (ADR 0001) — a note filed under one of four
/// Dots would be a note about that Category.
extension JournalStore {
    public var dayNotesFileURL: URL { directoryURL.appendingPathComponent("notes.jsonl") }

    // MARK: - Writing

    /// Writes the day's note, or takes it away when nothing is left of it.
    ///
    /// Writing it *is* saving it: there is no Done button on a review, so the
    /// text that is on screen is the text that is on disk. A note emptied back
    /// to nothing is deleted rather than stored blank, so an untouched day and a
    /// day whose note was rubbed out look the same — which they are.
    public func setDayNote(_ text: String, on date: Date, at now: Date = Date()) throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let day = JournalDay(date, calendar: calendar)
        try JournalLog.append(
            trimmed.isEmpty
                ? DayNoteRecord(day: day, text: nil, updatedAt: now, removed: true)
                : DayNoteRecord(day: day, text: text, updatedAt: now),
            to: dayNotesFileURL
        )
    }

    // MARK: - Reading

    /// The note on a day, or `nil` when nothing was written — an empty field is
    /// the absence of a note, never an empty one.
    public func dayNote(on date: Date) -> String? {
        dayNote(on: JournalDay(date, calendar: calendar))
    }

    public func dayNote(on day: JournalDay) -> String? {
        replayDayNotes()[day]
    }

    /// Every note on file, by day. Keyed by the day rather than by an id, which
    /// is why the shared replay in ``JournalLog`` is not the one used here.
    private func replayDayNotes() -> [JournalDay: String] {
        var live: [JournalDay: String] = [:]
        for record in JournalLog.records(DayNoteRecord.self, at: dayNotesFileURL) {
            if record.removed {
                live[record.day] = nil
                continue
            }
            // A line with no text says nothing about what the day holds, and
            // must not wipe the note that is there.
            guard let text = record.text else { continue }
            live[record.day] = text
        }
        return live
    }
}
