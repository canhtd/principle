import Foundation
import Testing

@testable import PrincipleCore

@Suite("JournalStore — backlog")
struct JournalBacklogTests {
    @Test("The backlog reads under category headers, uncategorised last")
    func backlogGroupsUnderCategoryHeaders() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "green")
        try repo.journal.addTask(title: "English — 30 min", categoryID: learning.id)
        try repo.journal.addTask(title: "Walk", categoryID: health.id)
        try repo.journal.addTask(title: "Book flights")
        try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id)

        let groups = repo.journal.backlog()

        #expect(groups.map { $0.category?.name } == ["Learning", "Health", nil])
        #expect(groups[0].tasks.map(\.title) == ["English — 30 min", "Read 20 pages"])
        #expect(groups[1].tasks.map(\.title) == ["Walk"])
        #expect(groups[2].tasks.map(\.title) == ["Book flights"])
    }

    @Test("A category with nothing in it gets no header")
    func emptyCategoriesGetNoHeader() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        try repo.journal.addCategory(name: "Health", colorKey: "green")
        try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id)

        #expect(repo.journal.backlog().map { $0.category?.name } == ["Learning"])
    }

    @Test("A repeating task lives in its days, not in the backlog")
    func repeatingTasksAreNotInTheBacklog() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily)
        try repo.journal.addTask(title: "Book flights")

        #expect(repo.journal.backlog().flatMap { $0.tasks.map(\.title) } == ["Book flights"])
    }

    @Test("A finished one-off task leaves the backlog")
    func doneTasksLeaveTheBacklog() throws {
        let repo = try TempRepo(prefix: "journal")
        let flights = try repo.journal.addTask(title: "Book flights")
        var done = try #require(repo.journal.task(id: flights.id))
        done.isDone = true
        try repo.journal.save(done)

        #expect(repo.journal.backlog().isEmpty)
    }
}
