import Foundation
import Testing

@testable import PrincipleCore

/// The Day screen's model, driven the way the shell drives it: every assertion
/// is about what the screen would show after the write landed on disk.
@MainActor
@Suite("Day model")
struct JournalDayModelTests {
    /// A fixed instant so a test never straddles midnight on the machine
    /// running it, in the same UTC calendar `TempRepo` hands the store.
    static let noon: Date = {
        var components = DateComponents(year: 2026, month: 8, day: 17, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    private func makeModel(_ prefix: String) throws -> (JournalModel, TempRepo) {
        let repo = try TempRepo(prefix: prefix)
        return (JournalModel(store: repo.journal, day: Self.noon), repo)
    }

    @Test("Blocks and chips are split by whether they have a time")
    func splitsTheDay() throws {
        let (model, repo) = try makeModel("day-split")
        _ = repo
        let scheduled = model.createTask(at: TaskSchedule(startMinute: 9 * 60), title: "Decide M4 scope")
        model.logOutcome(title: "Unblocked Ha on the API", categoryID: nil)

        #expect(model.timed.map(\.title) == ["Decide M4 scope"])
        #expect(model.untimed.map(\.title) == ["Unblocked Ha on the API"])
        #expect(scheduled != nil)
    }

    @Test("An edit reaches the model's own task list, not just the file")
    func editsAreVisibleOnTheModel() throws {
        let (model, repo) = try makeModel("day-observe")
        _ = repo
        let id = try #require(model.createTask(at: TaskSchedule(startMinute: 9 * 60), title: "Decide M4 scope"))
        #expect(model.task(id: id)?.priority == .nice)

        model.setPriority(.must, taskID: id)

        // Through the model's held list — what the detail pane reads, and what
        // it can only redraw from if the value lives on the model itself.
        #expect(model.task(id: id)?.priority == .must)
        #expect(model.tasks.first { $0.id == id }?.priority == .must)
    }

    @Test("A logged outcome lands on the day already done")
    func loggedOutcomeIsDone() throws {
        let (model, repo) = try makeModel("day-log")
        _ = repo
        model.logOutcome(title: "A bad meeting", categoryID: nil)
        #expect(model.untimed.first?.isDone == true)
    }

    @Test("Blank text is not an outcome")
    func blankOutcomeIsDropped() throws {
        let (model, repo) = try makeModel("day-log-blank")
        _ = repo
        #expect(model.logOutcome(title: "   ", categoryID: nil) == nil)
        #expect(model.isEmptyDay)
    }

    @Test("Unticking a category takes its rows off the day and puts them back")
    func filtersByCategory() throws {
        let (model, repo) = try makeModel("day-filter")
        _ = repo
        let health = try #require(model.addCategory(name: "Health"))
        let work = try #require(model.addCategory(name: "Work"))
        let run = try #require(model.createTask(at: TaskSchedule(startMinute: 7 * 60), title: "Run"))
        let scope = try #require(model.createTask(at: TaskSchedule(startMinute: 9 * 60), title: "Scope"))
        model.setCategory(health.id, taskID: run)
        model.setCategory(work.id, taskID: scope)

        model.toggleVisibility(of: health.id)
        #expect(model.timed.map(\.title) == ["Scope"])
        #expect(model.taskCount == 1)

        model.toggleVisibility(of: health.id)
        #expect(model.timed.map(\.title) == ["Run", "Scope"])
    }

    @Test("Show only leaves one category ticked")
    func showOnly() throws {
        let (model, repo) = try makeModel("day-only")
        _ = repo
        let health = try #require(model.addCategory(name: "Health"))
        _ = model.addCategory(name: "Work")
        _ = model.addCategory(name: "Family")

        model.showOnly(categoryID: health.id)
        #expect(model.categories.filter(model.isShown).map(\.name) == ["Health"])

        model.showAllCategories()
        #expect(model.categories.allSatisfy(model.isShown))
    }

    @Test("Deleting a category keeps its work, untagged")
    func deletingACategoryKeepsItsTasks() throws {
        let (model, repo) = try makeModel("day-delete-category")
        _ = repo
        let health = try #require(model.addCategory(name: "Health"))
        let run = try #require(model.createTask(at: TaskSchedule(startMinute: 7 * 60), title: "Run"))
        model.setCategory(health.id, taskID: run)

        model.deleteCategory(id: health.id)
        #expect(model.categories.isEmpty)
        #expect(model.timed.map(\.title) == ["Run"])
        #expect(model.timed.first?.category == nil)
    }

    @Test("A category hidden and then deleted stops filtering anything")
    func deletingAHiddenCategoryClearsTheFilter() throws {
        let (model, repo) = try makeModel("day-delete-hidden")
        _ = repo
        let health = try #require(model.addCategory(name: "Health"))
        model.toggleVisibility(of: health.id)
        model.deleteCategory(id: health.id)
        #expect(model.hiddenCategoryIDs.isEmpty)
    }

    @Test("Renaming and recolouring a category survive a re-read")
    func renameAndRecolor() throws {
        let (model, repo) = try makeModel("day-category-edit")
        let category = try #require(model.addCategory(name: "Helth"))
        model.renameCategory(id: category.id, to: "Health")
        model.recolorCategory(id: category.id, to: "plum")

        let fresh = JournalModel(store: repo.journal, day: Self.noon)
        #expect(fresh.categories.map(\.name) == ["Health"])
        #expect(fresh.categories.map(\.colorKey) == ["plum"])
    }

    @Test("A new block takes the first category, so it is coloured from the start")
    func newBlockIsCategorised() throws {
        let (model, repo) = try makeModel("day-new-block")
        _ = repo
        let learning = try #require(model.addCategory(name: "Learning"))
        _ = model.createTask(at: TaskSchedule(startMinute: 14 * 60))
        #expect(model.timed.first?.category?.id == learning.id)
    }

    @Test("Dragging a chip onto the grid gives it a time and an hour")
    func chipBecomesABlock() throws {
        let (model, repo) = try makeModel("day-chip")
        _ = repo
        let task = try #require(model.logOutcome(title: "Buy groceries", categoryID: nil))
        model.schedule(taskID: task, startingAt: 16 * 60 + 7)

        let block = try #require(model.timed.first)
        #expect(block.schedule?.startMinute == 16 * 60)
        #expect(block.schedule?.durationMinutes == 60)
        #expect(model.untimed.isEmpty)
    }

    @Test("The soft-cap line appears past five tasks and says how many")
    func overloadLine() throws {
        let (model, repo) = try makeModel("day-overload")
        _ = repo
        for hour in 1...5 { _ = model.createTask(at: TaskSchedule(startMinute: hour * 60)) }
        #expect(model.overloadLine == nil)

        _ = model.createTask(at: TaskSchedule(startMinute: 6 * 60))
        #expect(model.overloadLine == "6 tasks — more than usual.")
    }

    @Test("Hidden rows do not count towards the soft cap")
    func overloadFollowsTheFilter() throws {
        let (model, repo) = try makeModel("day-overload-filter")
        _ = repo
        let work = try #require(model.addCategory(name: "Work"))
        for hour in 1...6 {
            let id = try #require(model.createTask(at: TaskSchedule(startMinute: hour * 60)))
            model.setCategory(work.id, taskID: id)
        }
        #expect(model.isOverloaded)

        model.toggleVisibility(of: work.id)
        #expect(model.isOverloaded == false)
        #expect(model.overloadLine == nil)
    }

    @Test("Suggestions are the backlog, and clicking one puts it on this day")
    func pullFromBacklog() throws {
        let (model, repo) = try makeModel("day-suggestions")
        let waiting = try repo.journal.addTask(title: "Call the doctor")
        model.refresh()
        #expect(model.suggestions.map(\.title) == ["Call the doctor"])

        model.pullIntoDay(taskID: waiting.id)
        #expect(model.untimed.map(\.title) == ["Call the doctor"])
        #expect(model.suggestions.isEmpty)
    }

    @Test("The header names the day, long and short")
    func dayTitles() throws {
        let (model, repo) = try makeModel("day-title")
        _ = repo
        #expect(model.dayTitle == "Monday, 17 August")
        #expect(model.shortDayTitle == "Mon 17 Aug")
        #expect(model.monthTitle == "August 2026")
    }

    @Test("Stepping a day moves the day and the mini calendar with it")
    func stepDays() throws {
        let (model, repo) = try makeModel("day-step")
        _ = repo
        model.shiftDay(by: 1)
        #expect(model.dayTitle == "Tuesday, 18 August")
        model.shiftDay(by: -3)
        #expect(model.dayTitle == "Saturday, 15 August")
        #expect(model.monthTitle == "August 2026")
    }

    @Test("Paging the mini calendar leaves the day where it is")
    func pageMonthsWithoutMovingTheDay() throws {
        let (model, repo) = try makeModel("day-month")
        _ = repo
        model.shiftMonth(by: 1)
        #expect(model.monthTitle == "September 2026")
        #expect(model.dayTitle == "Monday, 17 August")
    }

    @Test("Yesterday's blocks are not today's")
    func daysAreSeparate() throws {
        let (model, repo) = try makeModel("day-separate")
        _ = repo
        _ = model.createTask(at: TaskSchedule(startMinute: 9 * 60), title: "Only on the 17th")
        model.shiftDay(by: 1)
        #expect(model.isEmptyDay)
        model.shiftDay(by: -1)
        #expect(model.timed.map(\.title) == ["Only on the 17th"])
    }

    @Test("Ticking a block off is what a restart sees too")
    func doneSurvivesARestart() throws {
        let (model, repo) = try makeModel("day-done")
        let id = try #require(model.createTask(at: TaskSchedule(startMinute: 11 * 60), title: "English"))
        model.setDone(true, taskID: id)

        let fresh = JournalModel(store: repo.journal, day: Self.noon)
        #expect(fresh.timed.first?.isDone == true)
    }

    @Test("Moving a block writes the new time through")
    func moveABlock() throws {
        let (model, repo) = try makeModel("day-move")
        let id = try #require(model.createTask(at: TaskSchedule(startMinute: 9 * 60, durationMinutes: 90)))
        model.setSchedule(TaskSchedule(startMinute: 14 * 60, durationMinutes: 90), taskID: id)

        let fresh = JournalModel(store: repo.journal, day: Self.noon)
        #expect(fresh.timed.first?.schedule == TaskSchedule(startMinute: 840, durationMinutes: 90))
    }

    @Test("Taking a block's time off returns it to the all-day strip")
    func unscheduleABlock() throws {
        let (model, repo) = try makeModel("day-unschedule")
        _ = repo
        let id = try #require(model.createTask(at: TaskSchedule(startMinute: 9 * 60)))
        model.setSchedule(nil, taskID: id)
        #expect(model.timed.isEmpty)
        #expect(model.untimed.count == 1)
    }
}
