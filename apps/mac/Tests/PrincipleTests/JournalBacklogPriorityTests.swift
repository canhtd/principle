import Foundation
import Testing

@testable import PrincipleCore

/// The backlog as column 3 reads it: two groups, `Must do` before `Like to do`,
/// and the "+" in the header making a task that has no time yet.
@MainActor
@Suite("Backlog by priority")
struct JournalBacklogPriorityTests {
    /// A fixed instant, in the UTC calendar `TempRepo` hands the store, so a
    /// test never straddles midnight on the machine running it.
    private static let noon: Date = {
        var components = DateComponents(year: 2026, month: 8, day: 17, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()

    private func makeModel(_ prefix: String) throws -> (JournalModel, TempRepo) {
        let repo = try TempRepo(prefix: prefix)
        return (JournalModel(store: repo.journal, day: Self.noon), repo)
    }

    @Test("The backlog splits into what must happen and what would be nice to")
    func splitsByPriority() throws {
        let repo = try TempRepo(prefix: "backlog-priority")
        try repo.journal.addTask(title: "Call the doctor", priority: .must)
        try repo.journal.addTask(title: "Re-read Dalio chapter 5", priority: .nice)
        try repo.journal.addTask(title: "Fix the tax paperwork", priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        #expect(model.backlogTasks(priority: .must).map(\.title) == ["Call the doctor", "Fix the tax paperwork"])
        #expect(model.backlogTasks(priority: .nice).map(\.title) == ["Re-read Dalio chapter 5"])
    }

    @Test("A group with nothing in it comes back empty rather than missing")
    func emptyGroupIsEmpty() throws {
        let repo = try TempRepo(prefix: "backlog-one-group")
        try repo.journal.addTask(title: "Call the doctor", priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        #expect(model.backlogTasks(priority: .nice).isEmpty)
        #expect(model.backlogTasks(priority: .must).count == 1)
    }

    @Test("A task pulled into the day leaves both groups")
    func pulledTaskLeavesTheBacklog() throws {
        let repo = try TempRepo(prefix: "backlog-pull")
        let task = try repo.journal.addTask(title: "Call the doctor", priority: .must)
        let model = JournalModel(store: repo.journal, day: Self.noon)

        model.pullIntoDay(taskID: task.id)

        #expect(model.backlogTasks(priority: .must).isEmpty)
        #expect(model.untimed.map(\.title) == ["Call the doctor"])
    }

    @Test("The header's + makes a task on the day with no time yet")
    func createsAnUntimedTaskOnTheDay() throws {
        let (model, repo) = try makeModel("new-task-button")
        _ = repo

        let id = try #require(model.createTask())

        #expect(model.untimed.map(\.taskID) == [id])
        #expect(model.timed.isEmpty)
        // It belongs to the day, not to the backlog it would otherwise sit in.
        #expect(model.suggestions.isEmpty)
        #expect(model.task(id: id)?.schedule == nil)
    }
}
