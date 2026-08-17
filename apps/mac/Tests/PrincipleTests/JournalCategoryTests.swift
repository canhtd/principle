import Foundation
import Testing

@testable import PrincipleCore

@Suite("JournalStore — categories")
struct JournalCategoryTests {
    @Test("A created category is readable back through a fresh store")
    func createdCategorySurvivesRestart() throws {
        let repo = try TempRepo(prefix: "journal")

        let created = try repo.journal.addCategory(name: "Learning", colorKey: "blue")

        #expect(created.name == "Learning")
        let reloaded = repo.journal.categories()
        #expect(reloaded.map(\.id) == [created.id])
        #expect(reloaded.first?.colorKey == "blue")
    }

    @Test("Rename and recolor replace the old values, and nothing else moves")
    func renameAndRecolorRoundTrip() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learnign", colorKey: "blue")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "green")

        try repo.journal.renameCategory(id: learning.id, to: "Learning")
        try repo.journal.recolorCategory(id: learning.id, to: "violet")

        let reloaded = repo.journal.categories()
        #expect(reloaded.map(\.name) == ["Learning", "Health"])
        #expect(reloaded.map(\.colorKey) == ["violet", "green"])
        #expect(reloaded.map(\.id) == [learning.id, health.id])
    }

    @Test("A deleted category is gone from the list, the survivors keep their order")
    func deletedCategoryDisappears() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "green")

        try repo.journal.deleteCategory(id: learning.id)

        #expect(repo.journal.categories().map(\.id) == [health.id])
    }

    @Test("Deleting a category leaves its tasks in place, waiting to be re-tagged")
    func deletingACategoryLeavesItsTasksWithoutOne() throws {
        let repo = try TempRepo(prefix: "journal")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "blue")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "green")
        let english = try repo.journal.addTask(title: "English — 30 min", categoryID: learning.id)
        let walk = try repo.journal.addTask(title: "Walk", categoryID: health.id)

        try repo.journal.deleteCategory(id: learning.id)

        let tasks = repo.journal.tasks()
        #expect(tasks.map(\.title) == ["English — 30 min", "Walk"])
        #expect(try #require(tasks.first { $0.id == english.id }).categoryID == nil)
        #expect(try #require(tasks.first { $0.id == walk.id }).categoryID == health.id)

        // Re-tagging is an ordinary edit, and it sticks.
        var retagged = try #require(repo.journal.task(id: english.id))
        retagged.categoryID = health.id
        try repo.journal.save(retagged)
        #expect(try #require(repo.journal.task(id: english.id)).categoryID == health.id)
    }
}
