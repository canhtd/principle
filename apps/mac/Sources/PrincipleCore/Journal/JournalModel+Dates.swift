import Foundation

/// Which day the screen is on, and how it says so.
///
/// Split out of ``JournalModel`` itself only for room: the day the screen sits
/// on, the two arrows that move it and the wording of the header are one
/// subject, and the model file is at the size where a second one stops being
/// readable.
extension JournalModel {

    public var isToday: Bool { calendar.isDateInToday(day) }

    /// `Monday, 17 August` — English regardless of the Mac's region, like the
    /// rest of the app, and in the store's own time zone, so the header names
    /// the same day the sections were read for.
    public var dayTitle: String { format(day, as: "EEEE, d MMMM") }
    /// `Mon 17 Aug` — what a narrow window gets instead (decision 10).
    public var shortDayTitle: String { format(day, as: "EEE d MMM") }
    public var monthTitle: String { format(visibleMonth, as: "MMMM yyyy") }

    /// A fixed pattern rather than a locale's own order: the header is one line
    /// of the app's copy, and `Monday, August 17` is not the line the screen was
    /// drawn with.
    private func format(_ date: Date, as pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    /// Moves the screen to another day — what ‹ › and the mini calendar do, and
    /// what a relaunch after midnight needs.
    ///
    /// Whether the day being shown *is* today is answered here, once, while the
    /// answer is still knowable: an hour later "17 August" alone cannot say
    /// whether it was chosen or simply left behind by the clock (#17).
    public func show(day: Date, at now: Date = Date()) {
        self.day = day
        isFollowingToday = calendar.isDate(day, inSameDayAs: now)
        visibleMonth = day
        refresh()
    }

    public func shiftDay(by count: Int) {
        guard let moved = calendar.date(byAdding: .day, value: count, to: day) else { return }
        show(day: moved)
    }

    public func showToday() { show(day: Date()) }

    /// The whole of what midnight may do to the screen: a window left open on
    /// what *was* today shows the new day in the morning, and nothing else
    /// moves.
    ///
    /// The earlier version of this asked only whether the day on screen was
    /// behind the clock, which every browsed past day is — so a day opened to
    /// be reviewed was dragged back to today within the minute (#17).
    public func advanceIfDayRolledOver(at now: Date = Date()) {
        guard isFollowingToday, !calendar.isDate(day, inSameDayAs: now) else { return }
        show(day: now, at: now)
    }

    /// Pages the mini calendar without moving the day.
    public func shiftMonth(by count: Int) {
        guard let moved = calendar.date(byAdding: .month, value: count, to: visibleMonth) else { return }
        visibleMonth = moved
    }

}
