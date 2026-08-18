import Foundation
import Testing

@testable import PrincipleCore

@Suite("Day grid layout")
struct DayGridLayoutTests {
    private func row(_ start: Int, _ duration: Int, id: UUID = UUID()) -> PlannedTask {
        PlannedTask(
            taskID: id,
            day: JournalDay(year: 2026, month: 8, day: 17),
            title: "Block",
            category: nil,
            priority: .nice,
            note: "",
            schedule: TaskSchedule(startMinute: start, durationMinutes: duration),
            isDone: false,
            isRepeating: false
        )
    }

    @Test("A day of blocks that never overlap each keep the full width")
    func noOverlap() {
        let morning = row(9 * 60, 60)
        let afternoon = row(14 * 60, 60)
        let layout = DayGridLayout([morning, afternoon])
        #expect(layout.slot(for: morning.taskID) == .init(column: 0, columns: 1))
        #expect(layout.slot(for: afternoon.taskID) == .init(column: 0, columns: 1))
    }

    @Test("Two overlapping blocks split the width")
    func twoOverlap() {
        let first = row(9 * 60, 60)
        let second = row(9 * 60 + 30, 60)
        let layout = DayGridLayout([first, second])
        #expect(layout.slot(for: first.taskID) == .init(column: 0, columns: 2))
        #expect(layout.slot(for: second.taskID) == .init(column: 1, columns: 2))
        #expect(layout.slot(for: second.taskID).offsetFraction == 0.5)
        #expect(layout.slot(for: second.taskID).widthFraction == 0.5)
    }

    @Test("A block that ends exactly when the next starts does not overlap it")
    func touchingIsNotOverlapping() {
        let first = row(9 * 60, 60)
        let second = row(10 * 60, 60)
        let layout = DayGridLayout([first, second])
        #expect(layout.slot(for: first.taskID).columns == 1)
        #expect(layout.slot(for: second.taskID).columns == 1)
    }

    @Test("A busy morning does not narrow a quiet afternoon")
    func clustersAreIndependent() {
        let a = row(9 * 60, 60)
        let b = row(9 * 60, 60)
        let c = row(9 * 60, 60)
        let alone = row(15 * 60, 60)
        let layout = DayGridLayout([a, b, c, alone])
        #expect(layout.slot(for: a.taskID).columns == 3)
        #expect(layout.slot(for: alone.taskID).columns == 1)
    }

    @Test("A freed column is reused instead of widening the cluster")
    func reusesAFreedColumn() {
        let long = row(9 * 60, 180)
        let early = row(9 * 60, 60)
        let late = row(10 * 60 + 30, 60)
        let layout = DayGridLayout([long, early, late])
        #expect(layout.slot(for: long.taskID) == .init(column: 0, columns: 2))
        #expect(layout.slot(for: early.taskID).column == 1)
        // 10:30 is after the 09:00–10:00 block ended, so it takes that column
        // back rather than making the cluster three wide.
        #expect(layout.slot(for: late.taskID).column == 1)
    }

    @Test("The order blocks are handed over does not change where they land")
    func orderIndependent() {
        let first = row(9 * 60, 60)
        let second = row(9 * 60 + 30, 60)
        let forwards = DayGridLayout([first, second])
        let backwards = DayGridLayout([second, first])
        #expect(forwards.slot(for: first.taskID) == backwards.slot(for: first.taskID))
        #expect(forwards.slot(for: second.taskID) == backwards.slot(for: second.taskID))
    }

    @Test("A row with no time is drawn full width rather than not at all")
    func untimedRowFallsBack() {
        #expect(DayGridLayout([]).slot(for: UUID()) == .init(column: 0, columns: 1))
    }
}
