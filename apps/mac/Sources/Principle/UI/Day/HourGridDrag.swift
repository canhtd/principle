import DesignSystem
import PrincipleCore
import SwiftUI

/// The grid's half of a drag: pulling a new block out of empty canvas, moving
/// one, and resizing one. Split from ``HourGrid`` itself only because the file
/// was over 200 lines — it is the same view.
extension HourGrid {
    // MARK: - Dragging

    /// Dragging on empty canvas draws a new block out of it (decision 11: every
    /// edge lands on a quarter hour).
    var createGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                draft = .creating(
                    from: TaskSchedule.snap(DayMetric.minute(atY: value.startLocation.y)),
                    to: TaskSchedule.snap(DayMetric.minute(atY: value.location.y))
                )
            }
            .onEnded { _ in
                if let schedule = draft?.ghost, let id = journal.createTask(at: schedule) {
                    // Straight into column 3: a block called "New task" is only
                    // useful if it can be named without hunting for it.
                    ui.select(taskID: id)
                }
                draft = nil
            }
    }

    func move(_ row: PlannedTask, by offset: CGFloat) {
        guard let schedule = row.schedule else { return }
        let moved = schedule.starting(at: TaskSchedule.snap(schedule.startMinute + DayMetric.minute(atY: offset)))
        draft = .adjusting(taskID: row.taskID, schedule: moved)
    }

    func resize(_ row: PlannedTask, by offset: CGFloat) {
        guard let schedule = row.schedule else { return }
        let resized = schedule.ending(at: TaskSchedule.snap(schedule.endMinute + DayMetric.minute(atY: offset)))
        draft = .adjusting(taskID: row.taskID, schedule: resized)
    }

    /// One write at the end of the drag, not one per frame: every intermediate
    /// position would otherwise be a line in `tasks.jsonl`.
    func commit() {
        if case .adjusting(let taskID, let schedule) = draft {
            journal.setSchedule(schedule, taskID: taskID)
        }
        draft = nil
    }

    /// What a block should be drawn at right now — the drag in progress if it is
    /// the one being dragged, otherwise what is on disk.
    func schedule(for row: PlannedTask) -> TaskSchedule? {
        if case .adjusting(let taskID, let schedule) = draft, taskID == row.taskID { return schedule }
        return row.schedule
    }
}
