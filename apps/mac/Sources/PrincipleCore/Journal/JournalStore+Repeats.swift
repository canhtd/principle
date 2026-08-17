import Foundation

/// Turning repeat rules into rows a day can hold.
extension JournalStore {
    public var occurrencesFileURL: URL { directoryURL.appendingPathComponent("occurrences.jsonl") }

    /// Writes down the repeating rows this day is owed, and returns how many
    /// were new. Running it again on the same day writes nothing and returns 0:
    /// Today is opened many times a day, and a habit must appear once.
    ///
    /// Rows are written rather than derived on the fly so that a day keeps what
    /// it actually held: changing a habit's rule in September must not rewrite
    /// what August was asked to do.
    @discardableResult
    public func materialize(on date: Date, at now: Date = Date()) throws -> Int {
        let day = JournalDay(date, calendar: calendar)
        guard let weekday = weekday(of: date) else { return 0 }
        let existing = doneByTask(on: day)
        var written = 0
        // A habit added today was owed nothing last week: without the floor,
        // opening an older date would write rows into a past that never held
        // them, and the Chart would read a habit Danny never had.
        for task in tasks()
        where task.repeatRule.occurs(on: weekday)
            && JournalDay(task.createdAt, calendar: calendar) <= day
            && existing[task.id] == nil
        {
            try JournalLog.append(
                OccurrenceRecord(taskID: task.id, day: day, done: false, updatedAt: now),
                to: occurrencesFileURL
            )
            written += 1
        }
        return written
    }

    /// Ticks one day of a habit, leaving every other day of it alone.
    func setOccurrenceDone(_ done: Bool, taskID: UUID, on day: JournalDay, at now: Date) throws {
        try JournalLog.append(
            OccurrenceRecord(taskID: taskID, day: day, done: done, updatedAt: now),
            to: occurrencesFileURL
        )
    }

    /// The day's materialised rows: task id to whether it is ticked. Replayed in
    /// file order, so the last line about a pair is the one that counts.
    func doneByTask(on day: JournalDay) -> [UUID: Bool] {
        var state: [UUID: Bool] = [:]
        for record in JournalLog.records(OccurrenceRecord.self, at: occurrencesFileURL) where record.day == day {
            state[record.taskID] = record.done
        }
        return state
    }

    /// The weekday `date` falls on in this store's calendar. `nil` only for a
    /// calendar that answers something outside 1…7, which no Gregorian one does.
    func weekday(of date: Date) -> Weekday? {
        Weekday(calendarValue: calendar.component(.weekday, from: date))
    }
}
