import DesignSystem
import PrincipleCore
import SwiftUI

/// When a task runs: a start on the quarter hour, or All-day, and how long for.
///
/// Two menus rather than a stepper or a clock, because both answers come from a
/// short list — the grid can only hold quarter hours, and nothing here is
/// timed to the minute.
struct TimePicker: View {
    let schedule: TaskSchedule?
    let change: (TaskSchedule?) -> Void

    /// Every slot of the day: 96 of them, which is a long menu but a complete
    /// one — a shorter list would mean a time the grid can show and the detail
    /// cannot.
    private static let starts = stride(from: 0, to: TaskSchedule.dayMinutes, by: TaskSchedule.slotMinutes).map { $0 }
    /// The lengths a block actually turns out to be.
    private static let durations = [15, 30, 45, 60, 90, 120, 180, 240]

    var body: some View {
        HStack(spacing: EdenMetric.sidebarInset) {
            Picker("Start", selection: startBinding) {
                Text("All-day").tag(Int?.none)
                ForEach(Self.starts, id: \.self) { minute in
                    Text(TaskSchedule.label(minute: minute)).tag(Int?.some(minute))
                }
            }
            .labelsHidden()

            Picker("Duration", selection: durationBinding) {
                ForEach(Self.durations, id: \.self) { minutes in
                    Text(Self.durationLabel(minutes)).tag(minutes)
                }
            }
            .labelsHidden()
            .disabled(schedule == nil)
        }
        .font(EdenFont.ui(13))
    }

    private var startBinding: Binding<Int?> {
        Binding(
            get: { schedule?.startMinute },
            set: { start in
                guard let start else { return change(nil) }
                change(TaskSchedule(
                    startMinute: start,
                    durationMinutes: schedule?.durationMinutes ?? TaskSchedule.defaultDuration
                ))
            }
        )
    }

    private var durationBinding: Binding<Int> {
        Binding(
            get: { schedule?.durationMinutes ?? TaskSchedule.defaultDuration },
            set: { duration in
                guard let schedule else { return }
                change(TaskSchedule(startMinute: schedule.startMinute, durationMinutes: duration))
            }
        )
    }

    static func durationLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = Double(minutes) / 60
        let rounded = hours.rounded()
        let text = hours == rounded ? String(Int(rounded)) : String(format: "%.1f", hours)
        return "\(text) h"
    }
}
