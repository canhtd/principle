import Foundation
import Testing

@testable import PrincipleCore

/// What committing column 3's draft does to the journal — and, as much to the
/// point, what an abandoned draft does to it (spec #22: nothing).
@MainActor
@Suite("Creating a task from a draft")
struct JournalCreateTaskTests {
    private static let noon: Date = {
        var components = DateComponents(year: 2026, month: 8, day: 17, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    private func lines(_ repo: TempRepo) throws -> Int {
        let text = try String(contentsOf: repo.journal.tasksFileURL, encoding: .utf8)
        return text.split(separator: "\n").count
    }

    @Test("A committed draft arrives whole, not as four successive edits")
    func commitsEverythingAtOnce() throws {
        let repo = try TempRepo(prefix: "draft-commit")
        let model = JournalModel(store: repo.journal, day: Self.noon)
        let work = try #require(model.addCategory(name: "Work"))

        let id = try #require(model.createTask(
            title: "  Decide M4 scope  ",
            categoryID: work.id,
            priority: .must,
            note: "Bring both options.",
            schedule: TaskSchedule(startMinute: 9 * 60, durationMinutes: 90)
        ))

        let task = try #require(model.task(id: id))
        #expect(task.title == "Decide M4 scope")
        #expect(task.categoryID == work.id)
        #expect(task.priority == .must)
        #expect(task.note == "Bring both options.")
        #expect(task.schedule == TaskSchedule(startMinute: 9 * 60, durationMinutes: 90))
        #expect(model.timed.map(\.taskID) == [id])
        // The task and the day it was planned on — not one line per field.
        #expect(try lines(repo) == 2)
    }

    @Test("An abandoned draft writes nothing at all")
    func blankTitleWritesNothing() throws {
        let repo = try TempRepo(prefix: "draft-blank")
        let model = JournalModel(store: repo.journal, day: Self.noon)
        _ = model.createTask(at: TaskSchedule(startMinute: 8 * 60), title: "Something real")
        let before = try Data(contentsOf: repo.journal.tasksFileURL)

        let id = model.createTask(
            title: "   ",
            categoryID: nil,
            priority: .nice,
            schedule: TaskSchedule(startMinute: 11 * 60)
        )

        #expect(id == nil)
        // Byte-identical: a draft that was never named leaves no trace, which is
        // the whole promise of a draft.
        #expect(try Data(contentsOf: repo.journal.tasksFileURL) == before)
        #expect(model.timed.count == 1)
    }

    @Test("A repeating draft is left to its rule rather than planned on the day")
    func repeatingDraftIsNotPlanned() throws {
        let repo = try TempRepo(prefix: "draft-repeat")
        // Today rather than the fixed noon the other tests use: a repeating task
        // starts on the day it was made, and a rule cannot reach back to a day
        // before it existed. `.daily` matches whatever day that turns out to be,
        // so the test still does not depend on when it is run.
        let model = JournalModel(store: repo.journal, day: Date())

        let id = try #require(model.createTask(
            title: "English — 30 min",
            categoryID: nil,
            priority: .must,
            repeatRule: .daily,
            schedule: TaskSchedule(startMinute: 11 * 60, durationMinutes: 30)
        ))

        #expect(model.task(id: id)?.plannedDay == nil)
        // It is on the day all the same — by its rule, which is the point.
        #expect(model.timed.map(\.taskID) == [id])
        #expect(try lines(repo) == 1)
    }
}
