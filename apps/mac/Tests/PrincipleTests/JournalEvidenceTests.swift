import Foundation
import Testing

@testable import PrincipleCore

/// What the Review pane shows under the tracks: the tasks Danny ticked that day
/// for the track he picked, and the note he writes about the day (#15).
///
/// Model level rather than store level, because every claim is about the day the
/// screen is on — which the store cannot see.
@MainActor
@Suite("Review your day — evidence, the Bar and the Day note")
struct JournalEvidenceTests {
    private let monday = TempRepo.noon(august: 17)
    private let sunday = TempRepo.noon(august: 16)

    @Test("Evidence is what was ticked, grouped by category, and nothing else")
    func evidenceGroupsTickedTasksOnly() throws {
        let repo = try TempRepo(prefix: "evidence")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let scope = try repo.journal.addTask(title: "Decide M4 scope", categoryID: work.id)
        let call = try repo.journal.addTask(title: "Write the follow-up", categoryID: work.id)
        let run = try repo.journal.addTask(title: "Morning run", categoryID: health.id)
        for task in [scope, call, run] { try repo.journal.plan(taskID: task.id, on: monday) }
        try repo.journal.setDone(true, taskID: scope.id, on: monday)
        try repo.journal.setDone(true, taskID: run.id, on: monday)

        let model = JournalModel(store: repo.journal, day: monday)

        #expect(model.evidence(for: work.id).map(\.title) == ["Decide M4 scope"])
        #expect(model.evidence(for: health.id).map(\.title) == ["Morning run"])
        #expect(model.evidenceByCategory.keys.count == 2)
    }

    @Test("Unticking a task takes it out of the evidence and leaves the dot alone")
    func untickingMovesNoDot() throws {
        let repo = try TempRepo(prefix: "evidence")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let scope = try repo.journal.addTask(title: "Decide M4 scope", categoryID: work.id)
        try repo.journal.plan(taskID: scope.id, on: monday)
        let model = JournalModel(store: repo.journal, day: monday)
        model.setDot(7, for: work.id)

        model.setDone(true, taskID: scope.id)
        #expect(model.evidence(for: work.id).map(\.title) == ["Decide M4 scope"])
        #expect(model.dotHeight(for: work.id) == 7)

        model.setDone(false, taskID: scope.id)
        #expect(model.evidence(for: work.id).isEmpty)
        // Ticking is done, and nothing more: the judgement stays Danny's.
        #expect(model.dotHeight(for: work.id) == 7)
    }

    @Test("Evidence is the day on screen's, not today's")
    func evidenceFollowsTheDayShown() throws {
        let repo = try TempRepo(prefix: "evidence")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "moss")
        let read = try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id)
        try repo.journal.plan(taskID: read.id, on: sunday)
        try repo.journal.setDone(true, taskID: read.id, on: sunday)

        let model = JournalModel(store: repo.journal, day: monday)
        #expect(model.evidence(for: learning.id).isEmpty)

        model.show(day: sunday)
        #expect(model.evidence(for: learning.id).map(\.title) == ["Read 20 pages"])
    }

    @Test("The day note is saved as it is typed and follows the day on screen")
    func dayNoteSavesAndFollowsTheDay() throws {
        let repo = try TempRepo(prefix: "evidence")
        let model = JournalModel(store: repo.journal, day: monday)

        model.setDayNote("Work carried the day.")

        #expect(model.dayNote == "Work carried the day.")
        #expect(model.errorMessage == nil)
        // On disk, not only on screen: no Save button is coming to write it.
        #expect(repo.journal.dayNote(on: monday) == "Work carried the day.")

        // An older day is not a read-only day (story 14).
        model.show(day: sunday)
        #expect(model.dayNote == nil)
        model.setDayNote("Caught up the evening I missed.")
        #expect(repo.journal.dayNote(on: sunday) == "Caught up the evening I missed.")

        model.show(day: monday)
        #expect(model.dayNote == "Work carried the day.")
    }

    @Test("Writing the note it already has writes nothing")
    func unchangedNoteWritesNothing() throws {
        let repo = try TempRepo(prefix: "evidence")
        let model = JournalModel(store: repo.journal, day: monday)
        model.setDayNote("Same.")
        let afterFirst = try Data(contentsOf: repo.journal.dayNotesFileURL).count

        model.setDayNote("Same.")
        // And an empty field on a day that never had a note is not a change.
        model.show(day: sunday)
        model.setDayNote("")

        #expect(try Data(contentsOf: repo.journal.dayNotesFileURL).count == afterFirst)
    }

    @Test("The bar is written through the model and read back on the category")
    func barThroughTheModel() throws {
        let repo = try TempRepo(prefix: "evidence")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let model = JournalModel(store: repo.journal, day: monday)
        #expect(model.bar(for: health.id) == nil)

        model.setBar("Moved for half an hour.", for: health.id)

        #expect(model.bar(for: health.id) == "Moved for half an hour.")
        #expect(model.reviewCategories.first?.bar == "Moved for half an hour.")

        model.setBar("", for: health.id)
        #expect(model.bar(for: health.id) == nil)
    }
}
