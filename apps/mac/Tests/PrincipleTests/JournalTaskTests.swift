import Foundation
import Testing

@testable import PrincipleCore

@Suite("JournalStore — tasks")
struct JournalTaskTests {
    @Test("A task round-trips through the store with every detail field")
    func taskRoundTripsWithItsDetail() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")

        let created = try repo.journal.addTask(
            title: "English — 30 min",
            categoryID: learning.id,
            priority: .must,
            repeatRule: .daily,
            note: "Speaking, not grammar"
        )

        let reloaded = try #require(repo.journal.task(id: created.id))
        #expect(reloaded.title == "English — 30 min")
        #expect(reloaded.categoryID == learning.id)
        #expect(reloaded.priority == .must)
        #expect(reloaded.repeatRule == .daily)
        #expect(reloaded.note == "Speaking, not grammar")
        #expect(reloaded.plannedDay == nil)
        #expect(reloaded.isDone == false)
    }

    @Test("An edit is what reads back next time; the earlier version is history")
    func editIsWhatReadsBack() throws {
        let repo = try TempRepo(prefix: "journal")
        let created = try repo.journal.addTask(title: "Read", priority: .nice)

        var edited = try #require(repo.journal.task(id: created.id))
        edited.title = "Read 20 pages"
        edited.priority = .must
        edited.note = "Principles, chapter 5"
        try repo.journal.save(edited)

        let reloaded = try #require(repo.journal.task(id: created.id))
        #expect(reloaded.title == "Read 20 pages")
        #expect(reloaded.priority == .must)
        #expect(reloaded.note == "Principles, chapter 5")
        #expect(repo.journal.tasks().count == 1)
    }

    @Test("A deleted task is gone; the surviving tasks keep their order")
    func deletedTaskDisappears() throws {
        let repo = try TempRepo(prefix: "journal")
        let read = try repo.journal.addTask(title: "Read")
        let walk = try repo.journal.addTask(title: "Walk")

        try repo.journal.deleteTask(id: read.id)

        #expect(repo.journal.tasks().map(\.title) == ["Walk"])
        #expect(repo.journal.task(id: read.id) == nil)
        #expect(repo.journal.task(id: walk.id) != nil)
    }

    @Test("Re-tagging a task is one move, and clearing the tag is the same move")
    func retaggingATaskIsOneMove() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "green")
        let walk = try repo.journal.addTask(title: "Walk", categoryID: learning.id)

        try repo.journal.setCategory(health.id, taskID: walk.id)
        #expect(try #require(repo.journal.task(id: walk.id)).categoryID == health.id)

        try repo.journal.setCategory(nil, taskID: walk.id)
        #expect(try #require(repo.journal.task(id: walk.id)).categoryID == nil)
    }
}
