import Foundation

/// How often a task comes back.
///
/// Four kinds and no more (spec #5, #6): a habit is either a one-off, every day,
/// a chosen set of weekdays, or once a week. Everything else — "every second
/// Tuesday", end dates, counts — is deliberately not offered, so a repeating
/// task's days can always be answered from the weekday alone.
public enum RepeatRule: Equatable, Sendable {
    case none
    case daily
    /// Empty set repeats on no day at all; that is a rule that was half-set, not
    /// a rule that means "every day".
    case weekdays(Set<Weekday>)
    case weekly(Weekday)

    /// Whether a task with this rule belongs to `weekday`.
    public func occurs(on weekday: Weekday) -> Bool {
        switch self {
        case .none: false
        case .daily: true
        case .weekdays(let days): days.contains(weekday)
        case .weekly(let day): day == weekday
        }
    }

    /// True for anything that comes back by itself — the tasks that live in the
    /// day rather than in the backlog.
    ///
    /// A weekdays rule with nothing ticked is *not* one of them: it names no day
    /// to come back on, so the task waits in the backlog where it can be seen,
    /// instead of belonging to no day and no list at all.
    public var isRepeating: Bool {
        switch self {
        case .none: false
        case .daily: true
        case .weekdays(let days): !days.isEmpty
        case .weekly: true
        }
    }
}

extension RepeatRule: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, days, day
    }

    private enum Kind: String, Codable {
        case none, daily, weekdays, weekly
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .none {
        case .none:
            self = .none
        case .daily:
            self = .daily
        case .weekdays:
            self = .weekdays(Set(try container.decodeIfPresent([Weekday].self, forKey: .days) ?? []))
        case .weekly:
            // A hand-edited line that lost its day names no day at all. It reads
            // back as a one-off, so the task turns up in the backlog where it
            // can be seen and fixed, rather than vanishing from every day or
            // quietly becoming a different kind of repeat.
            guard let day = try container.decodeIfPresent(Weekday.self, forKey: .day) else {
                self = .none
                return
            }
            self = .weekly(day)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        case .daily:
            try container.encode(Kind.daily, forKey: .kind)
        case .weekdays(let days):
            try container.encode(Kind.weekdays, forKey: .kind)
            // Monday-first rather than set order, so the same rule always writes
            // the same line and a diff means a real change.
            try container.encode(days.sorted { $0.weekOrder < $1.weekOrder }, forKey: .days)
        case .weekly(let day):
            try container.encode(Kind.weekly, forKey: .kind)
            try container.encode(day, forKey: .day)
        }
    }
}
