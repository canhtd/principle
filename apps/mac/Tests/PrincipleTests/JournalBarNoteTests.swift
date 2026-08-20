import Foundation
import Testing

@testable import PrincipleCore

/// The two pieces of writing a review carries: the Bar a Category is judged
/// against, and the Day note under the tracks (#15).
///
/// Store level, against a throwaway repo, because every claim here is about
/// what survives a restart — the pane has no Save button to lean on.
@Suite("Journal — the Bar and the Day note")
struct JournalBarNoteTests {
    private let monday = TempRepo.noon(august: 17)
    private let tuesday = TempRepo.noon(august: 18)

    // MARK: - The Bar

    @Test("A category starts with no bar, and keeps the one it is given")
    func barRoundTrip() throws {
        let repo = try TempRepo(prefix: "bar")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        #expect(repo.journal.categories().first?.bar == nil)

        try repo.journal.setBar("Moved for half an hour and in bed before midnight.", categoryID: health.id)

        #expect(repo.journal.categories().first?.bar == "Moved for half an hour and in bed before midnight.")
    }

    @Test("Renaming or recolouring a category leaves its bar where it was")
    func barSurvivesTheOtherEdits() throws {
        let repo = try TempRepo(prefix: "bar")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        try repo.journal.setBar("One decision made and shipped.", categoryID: work.id)

        try repo.journal.renameCategory(id: work.id, to: "Vessa")
        try repo.journal.recolorCategory(id: work.id, to: "clay")

        let category = try #require(repo.journal.categories().first)
        #expect(category.name == "Vessa")
        #expect(category.colorKey == "clay")
        #expect(category.bar == "One decision made and shipped.")
    }

    @Test("An emptied bar is absent again, not a blank sentence")
    func clearingTheBarLeavesItUnset() throws {
        let repo = try TempRepo(prefix: "bar")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "moss")
        try repo.journal.setBar("Read something that changed my mind.", categoryID: learning.id)

        try repo.journal.setBar("   ", categoryID: learning.id)

        #expect(repo.journal.categories().first?.bar == nil)
    }

    @Test("A category written with no bar writes no bar into the file")
    func unsetBarIsAbsentFromTheFile() throws {
        let repo = try TempRepo(prefix: "bar")
        _ = try repo.journal.addCategory(name: "Family", colorKey: "plum")

        let written = try String(contentsOf: repo.journal.categoriesFileURL, encoding: .utf8)
        #expect(written.contains("\"bar\"") == false)
    }

    // MARK: - The Day note

    @Test("The day note is written, read back, and belongs to its own day")
    func dayNoteRoundTrip() throws {
        let repo = try TempRepo(prefix: "note")

        try repo.journal.setDayNote("Work carried the day. Ate badly again after 9pm.", on: monday)

        #expect(repo.journal.dayNote(on: monday) == "Work carried the day. Ate badly again after 9pm.")
        #expect(repo.journal.dayNote(on: tuesday) == nil)
    }

    @Test("Writing again replaces the note rather than adding a second one")
    func editingTheNoteOverwritesIt() throws {
        let repo = try TempRepo(prefix: "note")
        try repo.journal.setDayNote("First thought.", on: monday)

        try repo.journal.setDayNote("What I actually think.", on: monday)

        #expect(repo.journal.dayNote(on: monday) == "What I actually think.")
    }

    @Test("An emptied note is gone, and an untouched day never had one")
    func emptyNoteIsAbsent() throws {
        let repo = try TempRepo(prefix: "note")
        try repo.journal.setDayNote("Something.", on: monday)

        try repo.journal.setDayNote("  \n ", on: monday)

        #expect(repo.journal.dayNote(on: monday) == nil)
        #expect(repo.journal.dayNote(on: tuesday) == nil)
    }

    @Test("An older day's note is written and read like any other day's")
    func anOlderDayIsWritable() throws {
        let repo = try TempRepo(prefix: "note")
        try repo.journal.setDayNote("Today's.", on: tuesday)

        try repo.journal.setDayNote("Caught up the evening I missed.", on: monday)

        #expect(repo.journal.dayNote(on: monday) == "Caught up the evening I missed.")
        #expect(repo.journal.dayNote(on: tuesday) == "Today's.")
    }
}
