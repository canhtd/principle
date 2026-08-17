import Foundation
import Testing

@testable import PrincipleCore

/// August 2026: the 17th is a Monday, so `august(17 + n)` walks the week.
@Suite("JournalStore — repeat rules")
struct JournalRepeatTests {
    private let monday = TempRepo.noon(august: 17)
    private let tuesday = TempRepo.noon(august: 18)
    private let saturday = TempRepo.noon(august: 22)
    private let nextMonday = TempRepo.noon(august: 24)

    @Test("A daily habit shows up on each new day, and only once however often the day is opened")
    func dailyHabitAppearsOncePerDay() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "English — 30 min", priority: .must, repeatRule: .daily)

        #expect(try repo.journal.today(monday).must.map(\.title) == ["English — 30 min"])
        // Opening the same day again must not double the row.
        #expect(try repo.journal.today(monday).must.map(\.title) == ["English — 30 min"])
        #expect(try repo.journal.today(monday).nice.isEmpty)

        #expect(try repo.journal.today(tuesday).must.map(\.title) == ["English — 30 min"])
    }

    @Test("A weekdays habit shows up on its chosen days and on no other")
    func weekdaysHabitAppearsOnlyOnItsDays() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "Gym", repeatRule: .weekdays([.monday, .saturday]))

        #expect(try repo.journal.today(monday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(saturday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(tuesday).all.isEmpty)
        #expect(try repo.journal.today(nextMonday).nice.map(\.title) == ["Gym"])
    }

    @Test("A weekly habit comes back once a week, on its weekday")
    func weeklyHabitComesBackOnceAWeek() throws {
        let repo = try TempRepo(prefix: "journal")
        try repo.journal.addTask(title: "Weekly review", priority: .must, repeatRule: .weekly(.monday))

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
        try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily)

        #expect(try repo.journal.materialize(on: monday) == 1)
        #expect(try repo.journal.materialize(on: monday) == 0)
        #expect(try repo.journal.materialize(on: tuesday) == 1)
        #expect(try repo.journal.today(monday).all.count == 1)
    }

    @Test("Ticking a habit ticks that day only")
    func tickingAHabitIsPerDay() throws {
        let repo = try TempRepo(prefix: "journal")
        let english = try repo.journal.addTask(title: "English — 30 min", repeatRule: .daily)
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
            repeatRule: .daily
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
        let gym = try repo.journal.addTask(title: "Gym", repeatRule: .daily)
        _ = try repo.journal.today(monday)

        var weekly = try #require(repo.journal.task(id: gym.id))
        weekly.repeatRule = .weekly(.saturday)
        try repo.journal.save(weekly)

        #expect(try repo.journal.today(monday).nice.map(\.title) == ["Gym"])
        #expect(try repo.journal.today(tuesday).all.isEmpty)
        #expect(try repo.journal.today(saturday).nice.map(\.title) == ["Gym"])
    }
}
