import Foundation

/// Writing and reading tasks. The store's own file is about categories and
/// paths; this is the task half.
extension JournalStore {
    public var tasksFileURL: URL { directoryURL.appendingPathComponent("tasks.jsonl") }

    // MARK: - Write

    @discardableResult
    public func addTask(
        title: String,
        categoryID: UUID? = nil,
        priority: Priority = .nice,
        repeatRule: RepeatRule = .none,
        note: String = "",
        id: UUID = UUID(),
        at date: Date = Date()
    ) throws -> JournalTask {
        let task = JournalTask(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            categoryID: categoryID,
            priority: priority,
            repeatRule: repeatRule,
            note: note,
            createdAt: date
        )
        try save(task, at: date)
        return task
    }

    /// Persists a task as it now stands — the general edit. Read one, change the
    /// fields, hand it back.
    @discardableResult
    public func save(_ task: JournalTask, at date: Date = Date()) throws -> JournalTask {
        try JournalLog.append(TaskRecord(task, updatedAt: date), to: tasksFileURL)
        return task
    }

    /// Removes the task itself. Its past days keep whatever they recorded.
    public func deleteTask(id: UUID, at date: Date = Date()) throws {
        guard let task = task(id: id) else { return }
        try JournalLog.append(TaskRecord(task, updatedAt: date, removed: true), to: tasksFileURL)
    }

    // MARK: - Read

    /// Every live task, oldest first. A task pointing at a deleted category
    /// comes back with no category at all: the file keeps the old id as
    /// history, but nothing downstream ever sees an id it cannot resolve.
    public func tasks() -> [JournalTask] {
        let liveCategories = Set(categories().map(\.id))
        var order: [UUID] = []
        var live: [UUID: JournalTask] = [:]
        for record in JournalLog.records(TaskRecord.self, at: tasksFileURL) {
            if record.removed {
                live[record.id] = nil
                order.removeAll { $0 == record.id }
                continue
            }
            if live[record.id] == nil { order.append(record.id) }
            var task = record.task
            if let categoryID = task.categoryID, !liveCategories.contains(categoryID) {
                task.categoryID = nil
            }
            live[record.id] = task
        }
        return order.compactMap { live[$0] }
    }

    public func task(id: UUID) -> JournalTask? {
        tasks().first { $0.id == id }
    }
}
