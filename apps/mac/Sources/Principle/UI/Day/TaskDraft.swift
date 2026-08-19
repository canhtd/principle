import Foundation
import PrincipleCore

/// A task being written, which is not yet a task.
///
/// The "+" used to append two lines to `tasks.jsonl` before a single character
/// had been typed, so changing your mind left "New task" in the journal for
/// ever. Apple Calendar's new event is the model: a block appears on the grid
/// where you can see it, the inspector opens on its name, and nothing is
/// written until you say so. Cancel leaves the file exactly as it was.
///
/// Deliberately a value on the shell's state rather than a row in the store —
/// the whole point is that the store has never heard of it.
struct TaskDraft: Equatable {
    var title = ""
    var categoryID: UUID?
    var priority: Priority = .nice
    var repeatRule: RepeatRule = .none
    var note = ""
    /// `nil` is All-day, exactly as it is on a saved task.
    var schedule: TaskSchedule?

    /// What the grid writes on the block while the field is still empty.
    static let placeholder = "New task"

    var blockTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.placeholder : trimmed
    }

    /// A draft with nothing typed in it is not a task, and leaving it is not a
    /// decision to make one.
    var isNamed: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
