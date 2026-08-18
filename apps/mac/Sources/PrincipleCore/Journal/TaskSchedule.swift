import Foundation

/// Where a task sits on the day's hour grid: a start and how long it runs.
///
/// A task without one is not "at midnight" — it is untimed, and lives in the
/// all-day strip. That is why the whole thing is optional on the task rather
/// than a pair of fields that need a sentinel value between them.
///
/// Everything snaps to a quarter of an hour (spec #7, decision 11). Minute
/// precision was considered and dropped: a grid that can hold 08:07 is a grid
/// that has to draw 08:07, and nothing about a day is decided at that
/// resolution. Snapping in the initializer rather than at each call site means
/// a schedule that exists is always on a slot, however it was made — dragged,
/// typed, or read back from a hand-edited file.
public struct TaskSchedule: Equatable, Sendable {
    /// Minutes in one slot. Every start and every duration is a multiple.
    public static let slotMinutes = 15
    public static let dayMinutes = 24 * 60
    /// What a task gets when it lands on the grid without being told a length.
    public static let defaultDuration = 60

    /// Minutes from midnight, `0 ..< 1440`, always on a slot boundary.
    public let startMinute: Int
    /// At least one slot, and never past the end of the day.
    public let durationMinutes: Int

    /// Snaps and clamps into the day. There is no failable path: a start of
    /// 25:00 or a duration of −3 is a bug upstream, and refusing it here would
    /// only move the crash somewhere the user can see it.
    public init(startMinute: Int, durationMinutes: Int = TaskSchedule.defaultDuration) {
        let start = Self.snap(startMinute).clamped(to: 0...(Self.dayMinutes - Self.slotMinutes))
        let requested = Self.snap(durationMinutes)
        self.startMinute = start
        self.durationMinutes = max(Self.slotMinutes, min(requested, Self.dayMinutes - start))
    }

    /// Minutes from midnight where the task ends, never past 24:00.
    public var endMinute: Int { startMinute + durationMinutes }

    /// A new schedule ending at `minute` — what dragging the bottom edge does.
    /// An end dragged above the start collapses to one slot rather than
    /// inverting the block.
    public func ending(at minute: Int) -> TaskSchedule {
        TaskSchedule(startMinute: startMinute, durationMinutes: Self.snap(minute) - startMinute)
    }

    /// The same length moved to a new start — what dragging the block does.
    public func starting(at minute: Int) -> TaskSchedule {
        TaskSchedule(startMinute: minute, durationMinutes: durationMinutes)
    }

    /// Nearest slot boundary.
    public static func snap(_ minutes: Int) -> Int {
        Int((Double(minutes) / Double(slotMinutes)).rounded()) * slotMinutes
    }

    /// `07:00` — 24-hour, zero-padded, and the same string wherever a time is
    /// written, because the app's copy is English and does not follow the Mac's
    /// region (the way the day header does not either).
    public static func label(minute: Int) -> String {
        let clamped = minutes(inDay: minute)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    /// `09:00 – 10:30`, the line a block wears when it is tall enough.
    public var rangeLabel: String { "\(Self.label(minute: startMinute)) – \(Self.label(minute: endMinute))" }

    /// Wraps a minute onto the day. 24:00 is the one value that reads as the end
    /// of the day rather than the start of the next one, so it is kept.
    private static func minutes(inDay minute: Int) -> Int {
        min(max(0, minute), dayMinutes)
    }
}

extension TaskSchedule: Codable {
    private enum CodingKeys: String, CodingKey {
        case startMinute = "start_minute"
        case durationMinutes = "duration_minutes"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A hand-written line may name only a start; an hour is what the app
        // gives a block that arrives without a length anyway.
        self.init(
            startMinute: try container.decode(Int.self, forKey: .startMinute),
            durationMinutes: try container.decodeIfPresent(Int.self, forKey: .durationMinutes)
                ?? Self.defaultDuration
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(startMinute, forKey: .startMinute)
        try container.encode(durationMinutes, forKey: .durationMinutes)
    }
}

/// Local to this file: a general `Comparable` helper does not belong in the
/// library's public surface just because one initializer needs it.
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
