import Foundation
import Testing

@testable import PrincipleCore

/// August 2026: the 17th is a Monday, so `august(17 + n)` walks the week.
@Suite("JournalStore — repeat rules")
struct JournalRepeatTests {
    /// Every habit below is created a week before the days under test, so the
    /// suite means the same thing whenever it runs.
    private let created = TempRepo.noon(august: 10)
    private let monday = TempRepo.noon(august: 17)
    private let tuesday = TempRepo.noon(august: 18)
    private let saturday = TempRepo.noon(august: 22)
    private let nextMonday = TempRepo.noon(august: 24)

    @Test("A daily habit shows up on each new day, and only once however often the day is opened")
    func dailyHabitAppearsOncePerDay() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "English — 30 min", priority: .must, repeatRule: .daily, at: created)

        #expect(try repo.journal.today(monday).must.map(\.title) == ["English — 30 min"])
        // Opening the same day again must not double the row.
        #expect(try repo.journal.today(monday).must.map(\.title) == ["English — 30 min"])
        #expect(try repo.journal.today(monday).nice.isEmpty)

        #expect(try repo.journal.today(tuesday).must.map(\.title) == ["English — 30 min"])
    }

    @Test("A weekdays habit shows up on its chosen days and on no other")
    func weekdaysHabitAppearsOnlyOnItsDays() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "Gym", repeatRule: .weekdays([.monday, .saturday]), at: created)

        #expect(try repo.journal.today(monday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(saturday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(tuesday).all.isEmpty)
        #expect(try repo.journal.today(nextMonday).nice.map(\.title) == ["Gym"])
    }

    @Test("A weekly habit comes back once a week, on its weekday")
    func weeklyHabitComesBackOnceAWeek() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "Weekly review", priority: .must, repeatRule: .weekly(.monday), at: created)

        // Every day of the week between the two Mondays stays empty.
        for day in 18...23 {
            #expect(try repo.journal.today(TempRepo.noon(august: day)).all.isEmpty)
        }
        #expect(try repo.journal.today(monday).must.map(\.title) == ["Weekly review"])
        #expect(try repo.journal.today(nextMonday).must.map(\.title) == ["Weekly review"])
    }

    @Test("Materialising a day twice writes the row once")
    func materialisingIsIdempotent() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily, at: created)

        #expect(try repo.journal.materialize(on: monday) == 1)
        #expect(try repo.journal.materialize(on: monday) == 0)
        #expect(try repo.journal.materialize(on: tuesday) == 1)
        #expect(try repo.journal.today(monday).all.count == 1)
    }

    @Test("Ticking a habit ticks that day only")
    func tickingAHabitIsPerDay() throws {
        let repo = try TempRepo(prefix: "journal")
        let english = try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily, at: created)
        _ = try repo.journal.today(monday)

        try repo.journal.setDone(true, taskID: english.id, on: monday)

        #expect(try repo.journal.today(monday).nice.map(\.isDone) == [true])
        #expect(try repo.journal.today(tuesday).nice.map(\.isDone) == [false])

        // And the habit is still a habit: unticking Monday leaves Tuesday alone.
        try repo.journal.setDone(false, taskID: english.id, on: monday)
        #expect(try repo.journal.today(monday).nice.map(\.isDone) == [false])
        #expect(try repo.journal.today(tuesday).nice.map(\.isDone) == [false])
    }

    @Test("A habit lands in the section its priority names, and carries its category")
    func habitLandsInItsSectionWithItsCategory() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let english = try repo.journal.addTask(
            title: "English — 30 min",
            categoryID: learning.id,
            priority: .must,
            repeatRule: .daily,
            at: created
        )

        let row = try #require(try repo.journal.today(monday).must.first)
        #expect(row.taskID == english.id)
        #expect(row.category == learning)
        #expect(row.isRepeating)

        // Moving it to Nice-to moves every day it has not been through yet.
        try repo.journal.setPriority(.nice, taskID: english.id)
        #expect(try repo.journal.today(monday).must.isEmpty)
        #expect(try repo.journal.today(monday).nice.map(\.title) == ["English — 30 min"])
    }

    @Test("A day already written keeps its rows when the rule changes afterwards")
    func aPastDayKeepsWhatItHeld() throws {
        let repo = try TempRepo(prefix: "journal")
        let gym = try repo.journal.addTask(title: "Gym", repeatRule: .daily, at: created)
        _ = try repo.journal.today(monday)

        var weekly = try #require(repo.journal.task(id: gym.id))
        weekly.repeatRule = .weekly(.saturday)
        try repo.journal.save(weekly)

        #expect(try repo.journal.today(monday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(tuesday).all.isEmpty)
        #expect(try repo.journal.today(saturday).nice.map(\.title) == ["Gym"])
    }

    @Test("A habit is owed nothing for the days before it existed")
    func aHabitDoesNotBackfillThePast() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily, at: tuesday)

        #expect(try repo.journal.today(monday).all.isEmpty)
        #expect(try repo.journal.materialize(on: monday) == 0)
        #expect(try repo.journal.today(tuesday).nice.map(\.title) == ["English — 30 min"])
    }

    @Test("A habit whose rule names no day is offered as an ordinary backlog task")
    func aRuleThatNamesNoDayRepeatsOnNothing() throws {
        let repo = try TempRepo(prefix: "journal")
        let store = repo.journal
        try store.addTask(title: "Weekly review", repeatRule: .weekly(.monday), at: created)

        // A hand-edited line that lost its day — the file is Danny's to edit.
        let text = try String(contentsOf: store.tasksFileURL, encoding: .utf8)
        try Data(text.replacingOccurrences(of: #"{"day":"mon","kind":"weekly"}"#, with: #"{"kind":"weekly"}"#).utf8)
            .write(to: store.tasksFileURL)

        #expect(try repo.journal.today(monday).all.isEmpty)
        #expect(repo.journal.backlog().flatMap { $0.tasks.map(\.title) } == ["Weekly review"])
    }

    @Test("Pulling a habit into a day is refused rather than quietly ignored")
    func planningAHabitIsRefused() throws {
        let repo = try TempRepo(prefix: "journal")
        let english = try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily, at: created)

        #expect(throws: JournalError.taskRepeats(english.id)) {
            try repo.journal.plan(taskID: english.id, on: monday)
        }
        #expect(try repo.journal.today(monday).nice.count == 1)
    }

    @Test("A weekdays rule with no day ticked leaves the task in the backlog")
    func aWeekdaysRuleWithNoDaysStaysInTheBacklog() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "Gym", repeatRule: .weekdays([]), at: created)

        // Nowhere to appear must not mean nowhere to be found.
        #expect(try repo.journal.today(monday).all.isEmpty)
        #expect(try repo.journal.today(saturday).all.isEmpty)
        #expect(repo.journal.backlog().flatMap { $0.tasks.map(\.title) } == ["Gym"])
    }
}
