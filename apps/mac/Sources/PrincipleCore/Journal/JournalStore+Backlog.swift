import Foundation

/// A category header in the backlog and the tasks under it. `category` is `nil`
/// for the tasks that have none — the group that reads last, and the one
/// deleting a category fills up.
public struct BacklogGroup: Equatable, Sendable {
    public let category: JournalCategory?
    public let tasks: [JournalTask]

    public init(category: JournalCategory?, tasks: [JournalTask]) {
        self.category = category
        self.tasks = tasks
    }
}

extension JournalStore {
    /// The backlog, grouped under category headers (spec #9): categories in the
    /// order they were created, the uncategorised group last, and no header for
    /// a category holding nothing.
    ///
    /// What is *not* here is as much of the answer as what is: a repeating task
    /// arrives in its days by itself, a planned task is already in a day, and a
    /// finished one is done — none of the three is waiting to be picked.
    public func backlog() -> [BacklogGroup] {
        let waiting = tasks().filter { !$0.repeatRule.isRepeating && !$0.isDone && $0.plannedDay == nil }
        var byCategory: [UUID: [JournalTask]] = [:]
        var uncategorised: [JournalTask] = []
        for task in waiting {
            guard let categoryID = task.categoryID else {
                uncategorised.append(task)
                continue
            }
            byCategory[categoryID, default: []].append(task)
        }
        var groups = categories().compactMap { category -> BacklogGroup? in
            guard let tasks = byCategory[category.id] else { return nil }
            return BacklogGroup(category: category, tasks: tasks)
        }
        if !uncategorised.isEmpty {
            groups.append(BacklogGroup(category: nil, tasks: uncategorised))
        }
        return groups
    }
}
