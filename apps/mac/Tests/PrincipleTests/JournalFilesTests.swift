import Foundation
import Testing

@testable import PrincipleCore

/// The repo is the memory (spec #22): the journal has to be readable — and
/// recognisable — with nothing but a text editor.
@Suite("JournalStore — files in the repo")
struct JournalFilesTests {
    private func object(_ line: String) throws -> [String: Any] {
        try #require(try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
    }

    private func lines(at url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    @Test("Everything lands under journal/ in the repo, one line per change")
    func filesLandUnderTheJournalFolder() throws {
        let repo = try TempRepo(prefix: "journal")
        let store = repo.journal
        let learning = try store.addCategory(name: "Learning", colorKey: "blue")
        let english = try store.addTask(
            title: "English — 30 min",
            categoryID: learning.id,
            priority: .must,
            repeatRule: .weekdays([.wednesday, .monday]),
            note: "Speaking"
        )
        _ = try store.today(TempRepo.noon(august: 17))

        #expect(store.categoriesFileURL.path.hasSuffix("journal/categories.jsonl"))
        #expect(store.tasksFileURL.path.hasSuffix("journal/tasks.jsonl"))
        #expect(store.occurrencesFileURL.path.hasSuffix("journal/occurrences.jsonl"))

        let category = try object(try #require(try lines(at: store.categoriesFileURL).first))
        #expect(category["name"] as? String == "Learning")
        #expect(category["color"] as? String == "blue")

        let task = try object(try #require(try lines(at: store.tasksFileURL).first))
        #expect(task["title"] as? String == "English — 30 min")
        #expect(task["priority"] as? String == "must")
        #expect(task["note"] as? String == "Speaking")
        let rule = try #require(task["repeat"] as? [String: Any])
        #expect(rule["kind"] as? String == "weekdays")
        // Monday first, whatever order the set came in — the same rule always
        // writes the same line.
        #expect(rule["days"] as? [String] == ["mon", "wed"])

        let occurrence = try object(try #require(try lines(at: store.occurrencesFileURL).first))
        #expect(occurrence["task_id"] as? String == english.id.uuidString)
        #expect(occurrence["day"] as? String == "2026-08-17")
    }

    @Test("A day is written as a plain date, not as an instant")
    func plannedDayIsWrittenAsADate() throws {
        let repo = try TempRepo(prefix: "journal")
        let store = repo.journal
        let read = try store.addTask(title: "Read 20 pages")
        try store.plan(taskID: read.id, on: TempRepo.noon(august: 17))

        let latest = try object(try #require(try lines(at: store.tasksFileURL).last))
        #expect(latest["planned_day"] as? String == "2026-08-17")
    }

    @Test("A broken line costs that line only")
    func aBrokenLineCostsThatLineOnly() throws {
        let repo = try TempRepo(prefix: "journal")
        let store = repo.journal
        let first = try store.addTask(title: "Read 20 pages")
        let second = try store.addTask(title: "Walk")

        var written = try lines(at: store.tasksFileURL)
        written.insert("khong-phai-json", at: 1)
        try Data((written.joined(separator: "\n") + "\n").utf8).write(to: store.tasksFileURL)

        #expect(repo.journal.tasks().map(\.id) == [first.id, second.id])
    }
}
