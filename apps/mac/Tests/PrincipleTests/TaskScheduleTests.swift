import Foundation
import Testing

@testable import PrincipleCore

/// The one rule the whole grid rests on: a schedule is always on a quarter-hour
/// boundary and always inside the day, however it was made.
@Suite("Task schedule")
struct TaskScheduleTests {
    @Test("A start off the grid snaps to the nearest quarter hour")
    func snapsStart() {
        #expect(TaskSchedule(startMinute: 7 * 60 + 7).startMinute == 7 * 60)
        #expect(TaskSchedule(startMinute: 7 * 60 + 8).startMinute == 7 * 60 + 15)
        #expect(TaskSchedule(startMinute: 9 * 60 + 22).startMinute == 9 * 60 + 15)
    }

    @Test("A duration off the grid snaps too, and never goes under one slot")
    func snapsDuration() {
        #expect(TaskSchedule(startMinute: 60, durationMinutes: 50).durationMinutes == 45)
        #expect(TaskSchedule(startMinute: 60, durationMinutes: 1).durationMinutes == 15)
        #expect(TaskSchedule(startMinute: 60, durationMinutes: -30).durationMinutes == 15)
    }

    @Test("Nothing can be scheduled past the end of the day")
    func clampsIntoTheDay() {
        let late = TaskSchedule(startMinute: 23 * 60 + 30, durationMinutes: 180)
        #expect(late.endMinute == 24 * 60)
        #expect(TaskSchedule(startMinute: 25 * 60).startMinute == 23 * 60 + 45)
        #expect(TaskSchedule(startMinute: -60).startMinute == 0)
    }

    @Test("Dragging the bottom edge above the start leaves one slot, not a negative block")
    func resizeCollapses() {
        let block = TaskSchedule(startMinute: 9 * 60, durationMinutes: 90)
        #expect(block.ending(at: 10 * 60).durationMinutes == 60)
        #expect(block.ending(at: 8 * 60).durationMinutes == 15)
    }

    @Test("Moving a block keeps its length")
    func moveKeepsLength() {
        let moved = TaskSchedule(startMinute: 9 * 60, durationMinutes: 90).starting(at: 14 * 60 + 7)
        #expect(moved.startMinute == 14 * 60)
        #expect(moved.durationMinutes == 90)
    }

    @Test("Times read the same wherever the Mac's region is set")
    func labels() {
        #expect(TaskSchedule.label(minute: 0) == "00:00")
        #expect(TaskSchedule.label(minute: 9 * 60 + 5) == "09:05")
        #expect(TaskSchedule(startMinute: 9 * 60, durationMinutes: 90).rangeLabel == "09:00 – 10:30")
        #expect(TaskSchedule(startMinute: 23 * 60 + 45).rangeLabel == "23:45 – 24:00")
    }
}

/// A schedule has to survive the round trip through `tasks.jsonl` — a block
/// that moves back to the all-day strip on relaunch is the bug this catches.
@Suite("Scheduled tasks on disk")
struct JournalScheduleTests {
    @Test("A scheduled task reads back at the same time after a restart")
    func roundTrip() throws {
        let repo = try TempRepo(prefix: "schedule")
        let task = try repo.journal.addTask(
            title: "Decide M4 scope",
            schedule: TaskSchedule(startMinute: 9 * 60, durationMinutes: 90)
        )
        let reread = try #require(repo.journal.task(id: task.id))
        #expect(reread.schedule == TaskSchedule(startMinute: 540, durationMinutes: 90))
    }

    @Test("A task with no time reads back with none")
    func untimedRoundTrip() throws {
        let repo = try TempRepo(prefix: "schedule-none")
        let task = try repo.journal.addTask(title: "Fix tax paperwork")
        #expect(repo.journal.task(id: task.id)?.schedule == nil)
    }

    @Test("Setting a time, moving it, and taking it off again are all one field")
    func setAndClear() throws {
        let repo = try TempRepo(prefix: "schedule-set")
        let task = try repo.journal.addTask(title: "Morning run")

        try repo.journal.setSchedule(TaskSchedule(startMinute: 7 * 60, durationMinutes: 45), taskID: task.id)
        #expect(repo.journal.task(id: task.id)?.schedule?.startMinute == 420)

        try repo.journal.setSchedule(TaskSchedule(startMinute: 8 * 60, durationMinutes: 45), taskID: task.id)
        #expect(repo.journal.task(id: task.id)?.schedule?.startMinute == 480)

        try repo.journal.setSchedule(nil, taskID: task.id)
        #expect(repo.journal.task(id: task.id)?.schedule == nil)
    }

    @Test("Scheduling a task leaves everything else about it alone")
    func keepsOtherFields() throws {
        let repo = try TempRepo(prefix: "schedule-fields")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        let task = try repo.journal.addTask(
            title: "English",
            categoryID: learning.id,
            priority: .must,
            repeatRule: .daily,
            note: "30 min"
        )
        try repo.journal.setSchedule(TaskSchedule(startMinute: 11 * 60), taskID: task.id)

        let reread = try #require(repo.journal.task(id: task.id))
        #expect(reread.categoryID == learning.id)
        #expect(reread.priority == .must)
        #expect(reread.repeatRule == .daily)
        #expect(reread.note == "30 min")
    }

    @Test("The day splits into what the grid draws and what the all-day strip does")
    func daySplitsByTime() throws {
        let repo = try TempRepo(prefix: "schedule-day")
        let day = TaskScheduleFixtures.noon
        let late = try repo.journal.addTask(title: "Dinner", schedule: TaskSchedule(startMinute: 19 * 60))
        let early = try repo.journal.addTask(title: "Run", schedule: TaskSchedule(startMinute: 7 * 60))
        let loose = try repo.journal.addTask(title: "Groceries")
        for task in [late, early, loose] { try repo.journal.plan(taskID: task.id, on: day) }

        let sections = try repo.journal.today(day)
        #expect(sections.timed.map(\.title) == ["Run", "Dinner"])
        #expect(sections.untimed.map(\.title) == ["Groceries"])
    }

    @Test("A time set on a repeating task belongs to every day it comes back on")
    func repeatingKeepsItsTime() throws {
        let repo = try TempRepo(prefix: "schedule-repeat")
        let task = try repo.journal.addTask(
            title: "English",
            repeatRule: .daily,
            schedule: TaskSchedule(startMinute: 11 * 60, durationMinutes: 30),
            at: TaskScheduleFixtures.noon
        )
        let tomorrow = TaskScheduleFixtures.noon.addingTimeInterval(24 * 3600)

        let today = try repo.journal.today(TaskScheduleFixtures.noon)
        let next = try repo.journal.today(tomorrow)
        #expect(today.timed.first?.schedule?.startMinute == 660)
        #expect(next.timed.first?.schedule?.startMinute == 660)
        #expect(next.timed.first?.taskID == task.id)
    }
}

enum TaskScheduleFixtures {
    /// A fixed instant so a test never straddles midnight on the machine running it.
    static let noon: Date = {
        var components = DateComponents(year: 2026, month: 8, day: 17, hour: 12)
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }()
}
