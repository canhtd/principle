import Foundation
import Testing

@testable import PrincipleCore

/// What the minute clock is allowed to do to the day on screen (#17).
///
/// The rule is one sentence: the screen follows the clock only while it is
/// showing the day the clock put there. A day Danny opened from the mini month
/// is his, and stays his until he leaves it — reviewing an evening takes longer
/// than a minute, which is how the old check was found.
@MainActor
@Suite("Journal — the day on screen when the clock ticks")
struct JournalDayRolloverTests {
    private let seventeenth = TempRepo.noon(august: 17)
    private let twentieth = TempRepo.noon(august: 20)

    private func day(_ model: JournalModel) -> JournalDay {
        JournalDay(model.day, calendar: TempRepo.utcCalendar)
    }

    @Test("A day browsed to on purpose stays there while the clock ticks past it")
    func browsedDayStaysPut() throws {
        let repo = try TempRepo(prefix: "rollover")
        let model = JournalModel(store: repo.journal, day: twentieth, now: twentieth)

        model.show(day: seventeenth, at: twentieth)
        // Two minutes of the clock ticking, which is what broke it before.
        model.advanceIfDayRolledOver(at: twentieth.addingTimeInterval(60))
        model.advanceIfDayRolledOver(at: twentieth.addingTimeInterval(120))

        #expect(day(model) == JournalDay(year: 2026, month: 8, day: 17))
        #expect(model.isFollowingToday == false)
    }

    @Test("A window left open on today rolls over to the new day at midnight")
    func todayRollsOverAtMidnight() throws {
        let repo = try TempRepo(prefix: "rollover")
        let model = JournalModel(store: repo.journal, day: seventeenth, now: seventeenth)
        #expect(model.isFollowingToday)

        // The same instant a minute after midnight looks like on the 18th.
        model.advanceIfDayRolledOver(at: TempRepo.noon(august: 18))

        #expect(day(model) == JournalDay(year: 2026, month: 8, day: 18))
        // And it keeps following: the next midnight moves it again.
        #expect(model.isFollowingToday)
    }

    @Test("Pressing Today puts the screen back under the clock")
    func todayButtonRearmsTheFollow() throws {
        let repo = try TempRepo(prefix: "rollover")
        let model = JournalModel(store: repo.journal, day: twentieth, now: twentieth)
        model.show(day: seventeenth, at: twentieth)

        model.showToday()

        #expect(model.isFollowingToday)
        // `showToday` reads the real clock, so the roll-over is measured from it.
        let tomorrow = Date().addingTimeInterval(24 * 60 * 60)
        model.advanceIfDayRolledOver(at: tomorrow)
        #expect(day(model) == JournalDay(tomorrow, calendar: TempRepo.utcCalendar))
    }

    @Test("A tick on the day already shown changes nothing")
    func aTickOnTheSameDayIsNotAMove() throws {
        let repo = try TempRepo(prefix: "rollover")
        let model = JournalModel(store: repo.journal, day: seventeenth, now: seventeenth)

        model.advanceIfDayRolledOver(at: seventeenth.addingTimeInterval(60 * 60))

        #expect(day(model) == JournalDay(year: 2026, month: 8, day: 17))
    }
}
