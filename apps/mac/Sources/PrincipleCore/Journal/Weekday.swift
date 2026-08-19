import Foundation

/// A day of the week, as a repeat rule names it.
///
/// Written `mon`…`sun` in the files: `Calendar`'s numbering (Sunday is 1) is an
/// implementation detail nobody should have to remember while reading the repo.
/// `allCases` starts on Monday, which is the order the week is offered in.
public enum Weekday: String, CaseIterable, Codable, Sendable {
    case monday = "mon"
    case tuesday = "tue"
    case wednesday = "wed"
    case thursday = "thu"
    case friday = "fri"
    case saturday = "sat"
    case sunday = "sun"

    /// `Calendar.component(.weekday:)`'s value in the Gregorian calendar.
    public var calendarValue: Int {
        switch self {
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
    }

    public init?(calendarValue: Int) {
        guard let match = Self.allCases.first(where: { $0.calendarValue == calendarValue }) else { return nil }
        self = match
    }

    /// Monday first — the order a week is written and shown in.
    public var weekOrder: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    /// What "Weekdays" means before anything is ticked. Named here rather than
    /// spelled out at the one call site, because Mon–Fri is a fact about the
    /// week, not about the picker that offers it.
    public static let workingWeek: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]
}
