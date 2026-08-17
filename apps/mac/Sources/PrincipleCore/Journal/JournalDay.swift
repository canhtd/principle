import Foundation

/// One calendar day — the unit the Journal plans in.
///
/// A `Date` is an instant, and an instant read in another time zone is a
/// different day; "planned for the 17th" has to survive that. Stored as
/// `2026-08-17`, which is also what a human reading `journal/tasks.jsonl`
/// expects to see.
public struct JournalDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on *in this calendar* — which is where the time zone
    /// is decided, once, instead of at every call site.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// Midnight at the start of this day, or `nil` for a day that calendar has
    /// no instant for (a date that never existed in that time zone).
    public func startOfDay(in calendar: Calendar) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// `2026-08-17` — ISO order so a plain string sort is a date sort.
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Parses the written form back. Rejects anything that is not three numbers
    /// in `yyyy-MM-dd` shape rather than guessing at a hand-typed date.
    public init?(_ text: String) {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
            let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: JournalDay, rhs: JournalDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

extension JournalDay: Codable {
    /// A bare string in the file — `"2026-08-17"`, not an object of three numbers.
    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let parsed = JournalDay(text) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Not a yyyy-MM-dd day: \(text)")
            )
        }
        self = parsed
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
