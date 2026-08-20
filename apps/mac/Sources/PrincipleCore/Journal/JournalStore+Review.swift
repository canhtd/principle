import Foundation

/// Reviewing a day: one Dot per Category per day, in `journal/reviews.jsonl`
/// beside the tasks (ADR 0001).
extension JournalStore {
    public var reviewsFileURL: URL { directoryURL.appendingPathComponent("reviews.jsonl") }

    // MARK: - Writing

    /// Puts a Category's Dot at a height on a day, or moves the one already
    /// there. Writing it *is* saving it — there is no Close day.
    ///
    /// The Category's name and colour go into the line as they stand now, so the
    /// Dot still reads as itself once the Category is renamed, recoloured or
    /// deleted. An id nothing answers to is still written: a hand-edited
    /// `categories.jsonl` must not be able to swallow a judgement.
    public func setDot(_ height: Int, categoryID: UUID, on date: Date, at now: Date = Date()) throws {
        let category = categories().first { $0.id == categoryID }
        try JournalLog.append(
            ReviewRecord(
                day: JournalDay(date, calendar: calendar),
                categoryID: categoryID,
                height: JournalDot.clamp(height),
                categoryName: category?.name,
                colorKey: category?.colorKey,
                updatedAt: now
            ),
            to: reviewsFileURL
        )
    }

    /// Takes a judgement back: the Category goes to unset for that day, which is
    /// the absence of a Dot rather than a height of any kind.
    public func clearDot(categoryID: UUID, on date: Date, at now: Date = Date()) throws {
        try JournalLog.append(
            ReviewRecord(
                day: JournalDay(date, calendar: calendar),
                categoryID: categoryID,
                height: nil,
                categoryName: nil,
                colorKey: nil,
                updatedAt: now,
                removed: true
            ),
            to: reviewsFileURL
        )
    }

    // MARK: - Reading

    /// One day's Dots, by Category id. A Category with nothing to say that day
    /// is simply not in the dictionary.
    public func dots(on date: Date) -> [UUID: JournalDot] {
        dots(on: JournalDay(date, calendar: calendar))
    }

    public func dots(on day: JournalDay) -> [UUID: JournalDot] {
        replayDots()[day] ?? [:]
    }

    /// Every Dot on file, by day. The replay ``JournalLog`` does for the other
    /// files is keyed by a single id; this one is keyed by a *pair*, so it is
    /// spelled out here rather than bent into that shape.
    private func replayDots() -> [JournalDay: [UUID: JournalDot]] {
        var live: [JournalDay: [UUID: JournalDot]] = [:]
        for record in JournalLog.records(ReviewRecord.self, at: reviewsFileURL) {
            if record.removed {
                live[record.day]?[record.categoryID] = nil
                continue
            }
            // A line that carries no height says nothing about where the Dot
            // stands, and must not wipe the one that is there.
            guard let height = record.height else { continue }
            let previous = live[record.day]?[record.categoryID]
            live[record.day, default: [:]][record.categoryID] = JournalDot(
                day: record.day,
                categoryID: record.categoryID,
                height: height,
                categoryName: record.categoryName ?? previous?.categoryName ?? "",
                colorKey: record.colorKey ?? previous?.colorKey ?? JournalPalette.fallbackColorKey
            )
        }
        return live
    }
}
