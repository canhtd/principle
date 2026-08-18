import Foundation
import Observation
import os

/// What the Day screen reads and writes: one day on the grid, the backlog
/// beside it, and the categories both are filtered by.
///
/// Lives in the library rather than next to the views (same bargain as
/// ``FavoritesModel``) so the whole loop — action → appended line → replayed
/// state — is testable against a temp repo, with no SwiftUI in sight.
///
/// Every action writes through the store and then re-reads it. The files are a
/// few hundred lines of JSONL on local disk, and a re-read is what keeps the
/// screen honest about what a restart would show.
@MainActor
@Observable
public final class JournalModel {
    /// The day on screen, in the store's calendar.
    public private(set) var day: Date
    /// The month the mini calendar is showing, which is not always the month the
    /// day is in: paging ahead to look at September must not move the day.
    public private(set) var visibleMonth: Date
    public private(set) var sections: DaySections
    public private(set) var backlog: [BacklogGroup] = []
    public private(set) var categories: [JournalCategory] = []
    /// Categories unticked in column 1. Deliberately not persisted: a filter
    /// that survives a relaunch is a filter that can hide a whole category of
    /// work for weeks without anyone noticing it is on.
    public internal(set) var hiddenCategoryIDs: Set<UUID> = []
    /// The last write that did not land. Shown quietly rather than thrown away:
    /// a task that looks added but is not on disk is the one failure that costs
    /// Danny real work.
    public private(set) var errorMessage: String?

    let store: JournalStore

    private static let logger = Logger(subsystem: PrincipleInfo.bundleIdentifier, category: "JournalModel")

    /// More than this on one day and the header says so — a line, never a block
    /// (spec #11).
    public static let softCap = 5

    public init(store: JournalStore, day: Date = Date()) {
        self.store = store
        self.day = day
        visibleMonth = day
        sections = DaySections(day: JournalDay(day, calendar: store.calendar), must: [], nice: [])
        refresh()
    }

    public convenience init(repoURL: URL, day: Date = Date()) {
        self.init(store: JournalStore(repoURL: repoURL), day: day)
    }

    var calendar: Calendar { store.calendar }

    // MARK: - The day as the grid sees it

    /// Rows on the grid, with the unticked categories taken out.
    public var timed: [PlannedTask] { sections.timed.filter(isVisible) }
    /// Rows in the all-day strip, same filter.
    public var untimed: [PlannedTask] { sections.untimed.filter(isVisible) }
    /// Every row the day is showing — what the count and the soft cap are about.
    public var visibleTasks: [PlannedTask] { sections.all.filter(isVisible) }

    public var taskCount: Int { visibleTasks.count }
    public var isOverloaded: Bool { taskCount > Self.softCap }
    public var isEmptyDay: Bool { visibleTasks.isEmpty }

    /// `7 tasks — more than usual.`, or nothing at all. One line, no banner
    /// (decision 9).
    public var overloadLine: String? {
        guard isOverloaded else { return nil }
        return "\(taskCount) tasks — more than usual."
    }

    public func isVisible(_ row: PlannedTask) -> Bool {
        guard let id = row.category?.id else { return true }
        return !hiddenCategoryIDs.contains(id)
    }

    public func isShown(_ category: JournalCategory) -> Bool {
        !hiddenCategoryIDs.contains(category.id)
    }

    /// The whole task behind a row — what the detail pane opens on.
    public func task(id: UUID) -> JournalTask? { store.task(id: id) }

    /// Every backlog task in one flat list, in category order: column 3 suggests
    /// from the backlog without repeating its headers.
    public var suggestions: [JournalTask] { backlog.flatMap(\.tasks) }

    /// The backlog by priority rather than by category — the two groups column 3
    /// reads it in, in the order a day is filled: what must happen, then what
    /// would be nice to. Category order is kept inside each group, so a task
    /// does not move about between the two views of the same list.
    public func backlogTasks(priority: Priority) -> [JournalTask] {
        suggestions.filter { $0.priority == priority }
    }

    public func category(id: UUID?) -> JournalCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Dates

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
    public func show(day: Date) {
        self.day = day
        visibleMonth = day
        refresh()
    }

    public func shiftDay(by count: Int) {
        guard let moved = calendar.date(byAdding: .day, value: count, to: day) else { return }
        show(day: moved)
    }

    public func showToday() { show(day: Date()) }

    /// Pages the mini calendar without moving the day.
    public func shiftMonth(by count: Int) {
        guard let moved = calendar.date(byAdding: .month, value: count, to: visibleMonth) else { return }
        visibleMonth = moved
    }

    // MARK: - Reading

    /// Re-reads the day and the backlog from disk. Also what materialises the
    /// day's repeating rows, so opening a day is what makes a habit tickable.
    public func refresh() {
        do {
            sections = try store.today(day)
            backlog = store.backlog()
            categories = store.categories()
            // A category deleted while it was hidden would otherwise keep
            // filtering a day by an id nothing can untick again.
            hiddenCategoryIDs.formIntersection(Set(categories.map(\.id)))
        } catch {
            report(error)
        }
    }

    // MARK: - Writing

    /// Every action is the same three steps: write, re-read, and say so if the
    /// write did not land.
    func write(_ change: (JournalStore) throws -> Void) {
        do {
            try change(store)
            errorMessage = nil
        } catch {
            report(error)
        }
        refresh()
    }

    func report(_ error: any Error) {
        Self.logger.error("Journal write failed: \(String(describing: error), privacy: .public)")
        errorMessage = "That change could not be saved. Check the repo path in Settings."
    }
}

extension JournalModel {
    /// True when the day on screen is behind `date` — what an app left open
    /// overnight looks like in the morning.
    public func selectionIsStale(before date: Date) -> Bool {
        JournalDay(day, calendar: calendar) < JournalDay(date, calendar: calendar)
    }
}
