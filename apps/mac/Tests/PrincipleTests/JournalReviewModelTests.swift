import Foundation
import Testing

@testable import PrincipleCore

/// The Review pane's side of the model: the tracks it draws, and what setting
/// and clearing a Dot does to the day on screen. Model level rather than store
/// level, because every claim here is about the *day the screen is on* — which
/// the store cannot see.
@MainActor
@Suite("Review your day — the model behind the tracks")
struct JournalReviewModelTests {
    private static func noon(august day: Int) -> Date { TempRepo.noon(august: day) }

    @Test("Setting a dot writes it to the day on screen and shows it there")
    func setDotLandsOnTheDayShown() throws {
        let repo = try TempRepo(prefix: "review-model")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))

        model.setDot(8, for: health.id)

        #expect(model.dotHeight(for: health.id) == 8)
        #expect(model.errorMessage == nil)
        // On disk, not only in the model: no Save button is coming to write it.
        #expect(repo.journal.dots(on: Self.noon(august: 17))[health.id]?.height == 8)
    }

    @Test("Clicking the same step again clears the dot back to unset")
    func clearDotTakesTheJudgementBack() throws {
        let repo = try TempRepo(prefix: "review-model")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))
        model.setDot(8, for: health.id)

        model.clearDot(for: health.id)

        #expect(model.dotHeight(for: health.id) == nil)
        #expect(repo.journal.dots(on: Self.noon(august: 17)).isEmpty)
    }

    @Test("Moving the screen to another day shows that day's dots")
    func dotsFollowTheDayOnScreen() throws {
        let repo = try TempRepo(prefix: "review-model")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))
        model.setDot(9, for: work.id)

        model.show(day: Self.noon(august: 16))
        #expect(model.dotHeight(for: work.id) == nil)

        // An older day is not a read-only day: the missed evening can be caught up.
        model.setDot(3, for: work.id)
        #expect(repo.journal.dots(on: Self.noon(august: 16))[work.id]?.height == 3)

        model.show(day: Self.noon(august: 17))
        #expect(model.dotHeight(for: work.id) == 9)
    }

    @Test("Setting the height a dot already stands on writes nothing")
    func settingTheSameHeightIsNotAWrite() throws {
        let repo = try TempRepo(prefix: "review-model")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))

        // What a drag across one step and back looks like from here.
        model.setDot(6, for: work.id)
        model.setDot(6, for: work.id)
        model.setDot(6, for: work.id)

        let lines = try String(contentsOf: repo.journal.reviewsFileURL, encoding: .utf8)
            .split(separator: "\n")
        #expect(lines.count == 1)
    }

    @Test("Clearing a category that has no dot writes nothing")
    func clearingAnUnsetCategoryIsNotAWrite() throws {
        let repo = try TempRepo(prefix: "review-model")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))

        model.clearDot(for: work.id)

        #expect(!FileManager.default.fileExists(atPath: repo.journal.reviewsFileURL.path))
    }

    @Test("The tracks are the categories column 1 is showing")
    func tracksFollowTheCategoryFilter() throws {
        let repo = try TempRepo(prefix: "review-model")
        let learning = try repo.journal.addCategory(name: "Learning", colorKey: "olive")
        let health = try repo.journal.addCategory(name: "Health", colorKey: "clay")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))

        #expect(model.reviewCategories.map(\.name) == ["Learning", "Health"])

        model.toggleVisibility(of: learning.id)
        #expect(model.reviewCategories.map(\.id) == [health.id])
    }

    @Test("A write that cannot land says so rather than showing a dot that is not on disk")
    func aFailedWriteIsReported() throws {
        let repo = try TempRepo(prefix: "review-model")
        let work = try repo.journal.addCategory(name: "Work", colorKey: "blueberry")
        let model = JournalModel(store: repo.journal, day: Self.noon(august: 17))
        // The journal directory replaced by a file: the append has nowhere to go.
        try FileManager.default.removeItem(at: repo.journal.directoryURL)
        try "not a directory".write(to: repo.journal.directoryURL, atomically: true, encoding: .utf8)

        model.setDot(7, for: work.id)

        #expect(model.errorMessage != nil)
        #expect(model.dotHeight(for: work.id) == nil)
    }
}
