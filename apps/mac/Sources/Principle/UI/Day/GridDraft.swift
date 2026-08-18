import DesignSystem
import PrincipleCore
import SwiftUI

/// The two things a drag on the grid can be.
enum GridDraft {
    case creating(from: Int, to: Int)
    case adjusting(taskID: UUID, schedule: TaskSchedule)

    /// The dashed outline the drag leaves behind, or `nil` while a block is
    /// simply following the pointer.
    var ghost: TaskSchedule? {
        guard case .creating(let from, let to) = self else { return nil }
        return TaskSchedule(startMinute: min(from, to), durationMinutes: max(abs(to - from), TaskSchedule.slotMinutes))
    }
}

/// Anchors the scroll view can be sent to.
enum HourAnchor {
    static func id(hour: Int) -> String { "hour-\(hour)" }
}

/// The outline a create-drag leaves while the pointer is still down.
struct GhostBlock: View {
    let schedule: TaskSchedule

    var body: some View {
        RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
            .fill(EdenColor.primary80.opacity(0.14))
            .overlay {
                RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                    .strokeBorder(EdenColor.primary80, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
            .frame(height: DayMetric.height(ofMinutes: schedule.durationMinutes))
            .allowsHitTesting(false)
    }
}
