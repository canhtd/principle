import Foundation
import Testing

@testable import PrincipleCore

@Suite("JournalStore — today")
struct JournalTodayTests {
    private let monday = TempRepo.noon(august: 17)
    private let tuesday = TempRepo.noon(august: 18)

    @Test("Pulling a task into a day moves it out of the backlog and into that day only")
    func pullingATaskIntoADay() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let read = try repo.journal.addTask(title: "Read 20 pages", categoryID: learning.id)

        try repo.journal.plan(taskID: read.id, on: monday)

        let today = try repo.journal.today(monday)
        #expect(today.must.isEmpty)
        #expect(today.nice.map(\.title) == ["Read 20 pages"])
        #expect(today.nice.first?.category == learning)
        #expect(try repo.journal.today(tuesday).all.isEmpty)
        #expect(repo.journal.backlog().isEmpty)
    }

    @Test("Toggling Must/Nice moves the row between the two sections")
    func togglingPriorityMovesTheRowBetweenSections() throws {
        let repo = try TempRepo(prefix: "journal")
        let read = try repo.journal.addTask(title: "Read 20 pages", priority: .nice)
        try repo.journal.plan(taskID: read.id, on: monday)

        try repo.journal.setPriority(.must, taskID: read.id)
        var today = try repo.journal.today(monday)
        #expect(today.must.map(\.title) == ["Read 20 pages"])
        #expect(today.nice.isEmpty)

        try repo.journal.setPriority(.nice, taskID: read.id)
        today = try repo.journal.today(monday)
        #expect(today.must.isEmpty)
        #expect(today.nice.map(\.title) == ["Read 20 pages"])
    }

    @Test("Ticking a row marks that row done and takes the task off the backlog")
    func tickingARowMarksItDone() throws {
        let repo = try TempRepo(prefix: "journal")
        let read = try repo.journal.addTask(title: "Read 20 pages")
        try repo.journal.plan(taskID: read.id, on: monday)

        try repo.journal.setDone(true, taskID: read.id, on: monday)

        #expect(try repo.journal.today(monday).nice.map(\.isDone) == [true])
        #expect(repo.journal.backlog().isEmpty)

        // Unticking is the same move backwards — a mis-tick is not a dead end.
        try repo.journal.setDone(false, taskID: read.id, on: monday)
        #expect(try repo.journal.today(monday).nice.map(\.isDone) == [false])
    }

    @Test("Sending a row back to the backlog empties the day and refills the backlog")
    func sendingARowBackToTheBacklog() throws {
        let repo = try TempRepo(prefix: "journal")
        let read = try repo.journal.addTask(title: "Read 20 pages")
        try repo.journal.plan(taskID: read.id, on: monday)

        try repo.journal.sendBackToBacklog(taskID: read.id)

        #expect(try repo.journal.today(monday).all.isEmpty)
        #expect(repo.journal.backlog().flatMap { $0.tasks.map(\.title) } == ["Read 20 pages"])
    }

    @Test("Planning a task that is not there says so instead of writing a ghost row")
    func planningAnUnknownTaskThrows() throws {
        let repo = try TempRepo(prefix: "journal")
        let unknown = UUID()

        #expect(throws: JournalError.taskNotFound(unknown)) {
            try repo.journal.plan(taskID: unknown, on: monday)
        }
        #expect(try repo.journal.today(monday).all.isEmpty)
    }
}
