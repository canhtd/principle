import DesignSystem
import PrincipleCore
import SwiftUI

/// When a task runs, the way Apple Calendar asks it: an All-day switch, and
/// under it — only when the switch is off — a `Starts` row and an `Ends` row.
///
/// The model underneath is unchanged: a start and a duration, every edge on a
/// quarter hour (decision 11). `Ends` is the derived one — it is what a person
/// knows ("until half ten"), while a duration is what the grid needs, and the
/// arithmetic between them belongs here rather than in anyone's head.
///
/// Changing `Starts` moves the block and keeps its length, which is what
/// Calendar does; changing `Ends` sets the length.
struct TimeFields: View {
    let schedule: TaskSchedule?
    let change: (TaskSchedule?) -> Void

    /// Every slot of the day: 96 of them, which is a long menu but a complete
    /// one — a shorter list would mean a time the grid can show and the detail
    /// cannot.
    private static let starts = Array(stride(from: 0, to: TaskSchedule.dayMinutes, by: TaskSchedule.slotMinutes))

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Toggle("All-day", isOn: allDayBinding)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(EdenFont.ui(13))
                .foregroundStyle(EdenColor.textPrimary)

            if let schedule {
                row("Starts", minutes: Self.starts, selection: startBinding(schedule))
                row("Ends", minutes: ends(after: schedule.startMinute), selection: endBinding(schedule))
            }
        }
    }

    private func row(_ label: String, minutes: [Int], selection: Binding<Int>) -> some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            Text(label)
                .font(EdenFont.ui(13))
                .foregroundStyle(EdenColor.hex(0x55524E))
                .frame(width: 44, alignment: .leading)
            Picker(label, selection: selection) {
                ForEach(minutes, id: \.self) { minute in
                    Text(TaskSchedule.label(minute: minute)).tag(minute)
                }
            }
            .labelsHidden()
            .font(EdenFont.ui(13))
        }
    }

    /// An end is any slot after the start, up to midnight — 24:00 reads as the
    /// end of this day rather than the start of the next.
    private func ends(after start: Int) -> [Int] {
        Array(stride(
            from: start + TaskSchedule.slotMinutes,
            through: TaskSchedule.dayMinutes,
            by: TaskSchedule.slotMinutes
        ))
    }

    /// All-day is the absence of a schedule, not a flag beside one: a task with
    /// no time is not at midnight, it is in the all-day strip.
    private var allDayBinding: Binding<Bool> {
        Binding(
            get: { schedule == nil },
            set: { isAllDay in
                change(isAllDay ? nil : TaskSchedule(startMinute: TimeFields.defaultStart))
            }
        )
    }

    private func startBinding(_ schedule: TaskSchedule) -> Binding<Int> {
        Binding(
            get: { schedule.startMinute },
            set: { change(schedule.starting(at: $0)) }
        )
    }

    private func endBinding(_ schedule: TaskSchedule) -> Binding<Int> {
        Binding(
            get: { schedule.endMinute },
            set: { change(schedule.ending(at: $0)) }
        )
    }

    /// The hour a task gets when All-day is switched off: mid-morning, not
    /// midnight, so the block lands where the day is rather than off the top of
    /// the grid.
    static let defaultStart = 9 * 60
}
