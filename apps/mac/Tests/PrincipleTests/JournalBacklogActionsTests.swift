import Foundation
import Testing

@testable import PrincipleCore

/// What column 3's backlog can do to a task, and what column 1's ticks do to the
/// backlog. Model level rather than store level: every one of these is a rule
/// about the two lists agreeing with each other, which the store cannot see.
@MainActor
@Suite("Backlog — filtering, scheduling, re-tagging")
struct JournalBacklogActionsTests {
    /// A fixed instant, in the UTC calendar `TempRepo` hands the store, so a
    /// test never straddles midnight on the machine running it.
    private static let noon: Date = {
        var components = DateComponents(year: 2026, month: 8, day: 17, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    @Test("Unticking a category takes its backlog rows off the list too")
    func backlogFollowsTheCategoryFilter() throws {
        let repo = try TempRepo(prefix: "backlog-filter")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id, priority: .must)
        try repo.journal.addTask(title: "Walk", categoryID: health.id, priority: .must)
        try repo.journal.addTask(title: "Book flights", priority: .nice)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.toggleVisibility(of: learning.id)

        #expect(model.backlogTasks(priority: .must).map(\.title) == ["Walk"])
        // An untagged task has no tick standing for it, so no tick can hide it.
        #expect(model.backlogTasks(priority: .nice).map(\.title) == ["Book flights"])
        // The unfiltered list is still the whole list — the filter is a view.
        #expect(model.suggestions.count == 3)
    }

    @Test("Ticking the category back on brings its backlog rows back")
    func filterIsReversible() throws {
        let repo = try TempRepo(prefix: "backlog-filter-back")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id, priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.toggleVisibility(of: learning.id)
        #expect(model.visibleSuggestions.isEmpty)
        model.toggleVisibility(of: learning.id)

        #expect(model.visibleSuggestions.map(\.title) == ["Read 20 pages"])
    }

    @Test("A backlog row dropped on the grid joins the day and takes that time")
    func droppingABacklogRowSchedulesItOnTheDay() throws {
        let repo = try TempRepo(prefix: "backlog-drop")
        let task = try repo.journal.addTask(title: "Call the doctor", priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.schedule(taskID: task.id, startingAt: 14 * 60)

        #expect(model.suggestions.isEmpty)
        #expect(model.timed.map(\.title) == ["Call the doctor"])
        #expect(model.task(id: task.id)?.schedule?.startMinute == 14 * 60)
        #expect(model.task(id: task.id)?.plannedDay == JournalDay(Self.noon, calendar: TempRepo.utcCalendar))
    }

    @Test("An all-day row dropped on the grid only changes its time")
    func droppingAnAllDayRowKeepsItsDay() throws {
        let repo = try TempRepo(prefix: "allday-drop")
        let task = try repo.journal.addTask(title: "Call the doctor", priority: .must)
        try repo.journal.plan(taskID: task.id, on: Self.noon)
        let model = JournalModel(store: repo.journal, day: Self.noon)
        #expect(model.untimed.count == 1)

        model.schedule(taskID: task.id, startingAt: 9 * 60 + 7)

        // 09:07 is not a slot; everything on the grid is on the quarter hour.
        #expect(model.task(id: task.id)?.schedule?.startMinute == 9 * 60)
        #expect(model.timed.map(\.title) == ["Call the doctor"])
    }

    @Test("The '+ Today' action puts a backlog row in the all-day strip")
    func pullingABacklogRowLeavesItUntimed() throws {
        let repo = try TempRepo(prefix: "backlog-pull-untimed")
        let task = try repo.journal.addTask(title: "Book flights", priority: .nice)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.pullIntoDay(taskID: task.id)

        #expect(model.untimed.map(\.title) == ["Book flights"])
        #expect(model.task(id: task.id)?.schedule == nil)
    }

    @Test("Deleting a category leaves its backlog rows on the list, untagged")
    func deletingACategoryRetagsItsBacklogRows() throws {
        let repo = try TempRepo(prefix: "backlog-delete-category")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let reading = try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id, priority: .must)
        try repo.journal.addTask(title: "Walk", categoryID: health.id, priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.deleteCategory(id: learning.id)

        #expect(model.categories.map(\.name) == ["Health"])
        // The work survives its label — and stays on the list, waiting to be
        // re-tagged rather than disappearing with the category.
        #expect(model.backlogTasks(priority: .must).map(\.title) == ["Walk", "Read 20 pages"])
        #expect(model.task(id: reading.id)?.categoryID == nil)

        model.setCategory(health.id, taskID: reading.id)
        #expect(model.task(id: reading.id)?.categoryID == health.id)
    }

    @Test("Deleting a backlog row takes it off the list and leaves nothing to report")
    func deletingABacklogRowIsClean() throws {
        let repo = try TempRepo(prefix: "backlog-delete-task")
        let task = try repo.journal.addTask(title: "Book flights", priority: .nice)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.deleteTask(id: task.id)
        // The detail pane writes its fields back as it is torn down, and the
        // delete is what tore it down. Neither may resurrect the row or set the
        // "could not be saved" line under it.
        model.setTitle("Book flights", taskID: task.id)
        model.setNote("via Skyscanner", taskID: task.id)

        #expect(model.suggestions.isEmpty)
        #expect(model.task(id: task.id) == nil)
        #expect(model.errorMessage == nil)
    }

    @Test("A category deleted while it was hidden stops filtering anything")
    func deletingAHiddenCategoryClearsTheFilter() throws {
        let repo = try TempRepo(prefix: "backlog-delete-hidden")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id, priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.toggleVisibility(of: learning.id)
        model.deleteCategory(id: learning.id)

        #expect(model.hiddenCategoryIDs.isEmpty)
        #expect(model.backlogTasks(priority: .must).map(\.title) == ["Read 20 pages"])
    }
}
