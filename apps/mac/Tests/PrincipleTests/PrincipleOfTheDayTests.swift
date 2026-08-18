import Foundation
import Testing

@testable import PrincipleCore

@Suite("Principle of the day")
struct PrincipleOfTheDayTests {
    @Test("The same day always gives the same principle")
    func stableByDay() {
        let day = JournalDay(year: 2026, month: 8, day: 17)
        #expect(PrincipleOfTheDay.index(for: day, count: 400) == PrincipleOfTheDay.index(for: day, count: 400))
    }

    @Test("Consecutive days land far apart, not on the next principle along")
    func neighbouringDaysAreNotNeighbouringPrinciples() {
        let first = PrincipleOfTheDay.index(for: JournalDay(year: 2026, month: 8, day: 17), count: 400)
        let second = PrincipleOfTheDay.index(for: JournalDay(year: 2026, month: 8, day: 18), count: 400)
        #expect(abs(first - second) > 1)
    }

    @Test("A fortnight of days gives a fortnight of different principles")
    func noRepeatsInAFortnight() {
        let indices = (1...14).map {
            PrincipleOfTheDay.index(for: JournalDay(year: 2026, month: 8, day: $0), count: 400)
        }
        #expect(Set(indices).count == indices.count)
    }

    @Test("Every principle is reached before any is shown twice")
    func walksTheWholeCorpus() {
        let count = 400
        let start = JournalDay(year: 2026, month: 1, day: 1).daysSinceEpoch
        let seen = Set((0..<count).map { offset -> Int in
            let ordinal = start + offset
            return ((ordinal * PrincipleOfTheDay.stride) % count + count) % count
        })
        #expect(seen.count == count)
    }

    @Test("The index stays inside the corpus, however small it is")
    func staysInBounds() {
        for count in [1, 2, 7, 513] {
            for day in 1...28 {
                let index = PrincipleOfTheDay.index(for: JournalDay(year: 2026, month: 8, day: day), count: count)
                #expect((0..<count).contains(index))
            }
        }
    }

    @Test("A repo with no corpus in it simply has no principle of the day")
    func noCorpus() {
        #expect(PrincipleOfTheDay.principle(on: JournalDay(year: 2026, month: 8, day: 17),
                                            in: CorpusStore(records: [])) == nil)
    }

    @Test("Only numbered principles with a body can be the card")
    func skipsHeadingsAndOverviews() {
        let corpus = CorpusStore(records: [
            PrincipleRecord(id: "life:overview:0", part: "Nguyên tắc sống", chapter: "", num: "•",
                            title: "Overview", body: "Long body", hasBody: true),
            PrincipleRecord(id: "life:1.1", part: "Nguyên tắc sống", chapter: "1", num: "1.1",
                            title: "Heading only", body: "", hasBody: false),
            PrincipleRecord(id: "life:5.3", part: "Nguyên tắc sống", chapter: "5", num: "5.3",
                            title: "Real one", body: "Real body", hasBody: true),
        ])
        #expect(PrincipleOfTheDay.candidates(in: corpus).map(\.id) == ["life:5.3"])
        for day in 1...10 {
            let picked = PrincipleOfTheDay.principle(on: JournalDay(year: 2026, month: 8, day: day), in: corpus)
            #expect(picked?.id == "life:5.3")
        }
    }

    @Test("Days count forward one at a time across a month and a leap year")
    func daysSinceEpoch() {
        #expect(JournalDay(year: 1970, month: 1, day: 1).daysSinceEpoch == 0)
        #expect(JournalDay(year: 1970, month: 1, day: 2).daysSinceEpoch == 1)
        #expect(JournalDay(year: 1969, month: 12, day: 31).daysSinceEpoch == -1)
        let endOfMonth = JournalDay(year: 2026, month: 8, day: 31).daysSinceEpoch
        #expect(JournalDay(year: 2026, month: 9, day: 1).daysSinceEpoch == endOfMonth + 1)
        let leapDay = JournalDay(year: 2028, month: 2, day: 29).daysSinceEpoch
        #expect(JournalDay(year: 2028, month: 3, day: 1).daysSinceEpoch == leapDay + 1)
    }
}
