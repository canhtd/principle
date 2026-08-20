import Foundation
import Testing

@testable import PrincipleCore

/// Reviewing a day: one Dot per Category per day, set, moved, taken back
/// (ADR 0001, spec #14). Store level — every claim here is about what is on
/// disk, read back through a store that was not the one that wrote it.
@Suite("JournalStore — the day's dots")
struct JournalReviewTests {
    private static func noon(august day: Int) -> Date { TempRepo.noon(august: day) }

    @Test("A dot set on a day is readable back through a fresh store")
    func dotSurvivesRestart() throws {
        let repo = try TempRepo(prefix: "review")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")

        try repo.journal.setDot(7, categoryID: health.id, on: Self.noon(august: 17))

        let dot = try #require(repo.journal.dots(on: Self.noon(august: 17))[health.id])
        #expect(dot.height == 7)
        #expect(dot.categoryName == "Health")
        #expect(dot.colorKey == "clay")
    }

    @Test("Setting a dot again moves it — the day keeps one dot per category")
    func settingAgainOverwrites() throws {
        let repo = try TempRepo(prefix: "review")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")

        try repo.journal.setDot(3, categoryID: work.id, on: Self.noon(august: 17))
        try repo.journal.setDot(9, categoryID: work.id, on: Self.noon(august: 17))

        let dots = repo.journal.dots(on: Self.noon(august: 17))
        #expect(dots.count == 1)
        #expect(dots[work.id]?.height == 9)
    }

    @Test("Clearing a dot leaves the category unset, and nothing live in the file")
    func clearingLeavesItAbsent() throws {
        let repo = try TempRepo(prefix: "review")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        try repo.journal.setDot(8, categoryID: work.id, on: Self.noon(august: 17))

        try repo.journal.clearDot(categoryID: work.id, on: Self.noon(august: 17))

        #expect(repo.journal.dots(on: Self.noon(august: 17))[work.id] == nil)
        #expect(repo.journal.dots(on: Self.noon(august: 17)).isEmpty)
        // Unset is the absence of a dot, never a zero and never a five: the
        // file's last word on this pair must carry no height at all.
        let lines = try String(contentsOf: repo.journal.reviewsFileURL, encoding: .utf8)
            .split(separator: "\n")
        #expect(lines.count == 2)
        #expect(lines[1].contains("\"removed\":true"))
        #expect(!lines[1].contains("\"height\""))
    }

    @Test("A category with nothing to say that day writes nothing at all")
    func unsetCategoriesAreAbsent() throws {
        let repo = try TempRepo(prefix: "review")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        _ = try repo.journal.addCategory(name: "Family", colorKey: "plum")

        try repo.journal.setDot(6, categoryID: learning.id, on: Self.noon(august: 17))

        #expect(repo.journal.dots(on: Self.noon(august: 17)).map(\.key) == [learning.id])
        #expect(FileManager.default.contents(atPath: repo.journal.reviewsFileURL.path).map { data in
            String(decoding: data, as: UTF8.self).split(separator: "\n").count
        } == 1)
    }

    @Test("Each day keeps its own dots")
    func daysAreIsolated() throws {
        let repo = try TempRepo(prefix: "review")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")

        try repo.journal.setDot(2, categoryID: health.id, on: Self.noon(august: 16))
        try repo.journal.setDot(9, categoryID: health.id, on: Self.noon(august: 17))
        try repo.journal.clearDot(categoryID: health.id, on: Self.noon(august: 17))

        #expect(repo.journal.dots(on: Self.noon(august: 16))[health.id]?.height == 2)
        #expect(repo.journal.dots(on: Self.noon(august: 17))[health.id] == nil)
        #expect(repo.journal.dots(on: Self.noon(august: 18)).isEmpty)
    }

    @Test("A deleted category keeps its dots, under the name and colour it had")
    func deletedCategoryKeepsItsHistory() throws {
        let repo = try TempRepo(prefix: "review")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        try repo.journal.setDot(4, categoryID: health.id, on: Self.noon(august: 16))

        try repo.journal.deleteCategory(id: health.id)

        #expect(repo.journal.categories().isEmpty)
        let dot = try #require(repo.journal.dots(on: Self.noon(august: 16))[health.id])
        #expect(dot.height == 4)
        #expect(dot.categoryName == "Health")
        #expect(dot.colorKey == "clay")
    }

    @Test("A dot set after a rename carries the new name, the old one keeps the old")
    func renameShowsInLaterDotsOnly() throws {
        let repo = try TempRepo(prefix: "review")
        let work = try repo.journal.addCategory(name: "Vessa", colorKey: "blueberry")
        try repo.journal.setDot(5, categoryID: work.id, on: Self.noon(august: 16))

        try repo.journal.renameCategory(id: work.id, to: "Work")
        try repo.journal.setDot(5, categoryID: work.id, on: Self.noon(august: 17))

        #expect(repo.journal.dots(on: Self.noon(august: 16))[work.id]?.categoryName == "Vessa")
        #expect(repo.journal.dots(on: Self.noon(august: 17))[work.id]?.categoryName == "Work")
    }

    @Test("A height off the track is pulled onto it rather than dropped")
    func heightsAreClamped() throws {
        let repo = try TempRepo(prefix: "review")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")

        try repo.journal.setDot(14, categoryID: work.id, on: Self.noon(august: 17))
        try repo.journal.setDot(0, categoryID: work.id, on: Self.noon(august: 18))

        #expect(repo.journal.dots(on: Self.noon(august: 17))[work.id]?.height == 10)
        #expect(repo.journal.dots(on: Self.noon(august: 18))[work.id]?.height == 1)
    }

    @Test("A day nobody has reviewed has no dots, and no file to read them from")
    func emptyJournalHasNoDots() throws {
        let repo = try TempRepo(prefix: "review")
        #expect(repo.journal.dots(on: Self.noon(august: 17)).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: repo.journal.reviewsFileURL.path))
    }
}
