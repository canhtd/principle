import Foundation

/// The principle column 1 shows on a given day.
///
/// Deterministic by date: the same day always gives the same principle, on this
/// Mac and on any other, without anything being stored. That matters more than
/// variety here — a card that changed every time the view redrew would be
/// noise, and one that needed a file to remember its place would be a third
/// thing that can go out of sync with the corpus.
///
/// The walk is a stride rather than `index % count`: consecutive days would
/// otherwise hand back 5.1, 5.2, 5.3 — the same chapter for a fortnight — and
/// the point of the card is to meet a principle you were not already reading.
public enum PrincipleOfTheDay {
    /// Coprime with any corpus size that is not a multiple of it, so the walk
    /// visits every principle before repeating one.
    static let stride = 97

    /// The principles the card can land on: the ones with a real number and a
    /// body. A heading-only record *is* a principle (AE3), but a card whose
    /// whole content is its own title reads as a bug, and the overview entries
    /// are numbered `•` rather than `5.3`.
    public static func candidates(in corpus: CorpusStore) -> [PrincipleRecord] {
        corpus.records.filter { record in
            record.displayBody != nil && record.num.first?.isNumber == true
        }
    }

    /// The principle for `day`, or `nil` for a repo with no corpus in it — which
    /// is a normal checkout, since the translation is never committed.
    public static func principle(on day: JournalDay, in corpus: CorpusStore) -> PrincipleRecord? {
        let pool = candidates(in: corpus)
        guard !pool.isEmpty else { return nil }
        return pool[index(for: day, count: pool.count)]
    }

    /// Which one of `count` a day lands on. Kept separate so the rotation can be
    /// tested without a corpus on disk.
    static func index(for day: JournalDay, count: Int) -> Int {
        guard count > 0 else { return 0 }
        // Days since an arbitrary fixed date, counted on the proleptic
        // Gregorian calendar so no time zone is involved: the card must not
        // change because the Mac flew somewhere.
        let ordinal = day.daysSinceEpoch
        let stepped = ordinal.multipliedReportingOverflow(by: stride).partialValue
        return ((stepped % count) + count) % count
    }
}

extension JournalDay {
    /// Days from 1970-01-01, by the calendar arithmetic every proleptic
    /// Gregorian date agrees on. Used to walk the corpus, never to name an
    /// instant — which is why it does not go anywhere near a `Date`.
    var daysSinceEpoch: Int {
        // Howard Hinnant's civil-from-days, run backwards. Shifts the year to
        // start in March so the leap day lands at the end of a cycle and every
        // month length becomes a formula.
        let shifted = month <= 2 ? year - 1 : year
        let era = (shifted >= 0 ? shifted : shifted - 399) / 400
        let yearOfEra = shifted - era * 400
        let dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
}
