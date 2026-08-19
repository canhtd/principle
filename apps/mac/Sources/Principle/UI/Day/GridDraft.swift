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

/// The block a task being written wears on the grid (spec #22).
///
/// Dashed, like the outline a create-drag leaves, because it is the same
/// promise: this is where the task will be, and it is not a task yet. Filled in
/// its category's colour so the day it is joining is legible, and it carries the
/// name as it is typed — an empty field reads as "New task", the way Calendar's
/// does.
struct DraftBlock: View {
    let title: String
    let color: Color
    let schedule: TaskSchedule
    /// Taken rather than inherited: the fill and the dashes have to be sized
    /// with the block, the way ``TaskBlockView`` sizes its own — a frame put on
    /// the outside only centres a box that has already hugged its text.
    let width: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(EdenFont.ui(13, .medium))
                .lineLimit(1)
            if DayMetric.height(ofMinutes: schedule.durationMinutes) >= DayMetric.timeLineThreshold {
                Text(schedule.rangeLabel)
                    .font(EdenFont.ui(11))
                    .opacity(0.72)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(EdenColor.textPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .frame(
            width: width,
            height: DayMetric.height(ofMinutes: schedule.durationMinutes),
            alignment: .topLeading
        )
        .background(color.opacity(0.18), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: EdenRadius.sm, style: .continuous)
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .allowsHitTesting(false)
    }
}
