import DesignSystem
import PrincipleCore
import SwiftUI

/// Column 2's toolbar: the date on the left, the time axis dead centre
/// (decision 1), and — only when a panel has become a drawer — the button that
/// slides it back in.
struct DayHeader: View {
    @Bindable var journal: JournalModel
    @Bindable var ui: DayShellState
    let isNarrow: Bool
    let showsSidebarToggle: Bool
    let showsDetailToggle: Bool
    /// Native full screen has no traffic lights on the window, so this header
    /// stops reserving the room for them.
    var isFullScreen = false

    /// Close, minimise and zoom, plus the gap after them.
    static let trafficLightWidth: CGFloat = 72

    var body: some View {
        // The axis is laid over the row rather than sitting in it (decision 1):
        // in a three-cell stack the date title sets its own width first and
        // pushes the control off to the right, and "centred" has to mean centred
        // on the column — including when a traffic-light inset has moved the
        // title in, which is why the overlay goes outside that padding.
        ZStack {
            HStack(spacing: EdenMetric.sidebarPadding) {
                title
                Spacer(minLength: EdenMetric.sidebarPadding)
                trailing
            }
            .padding(.horizontal, isNarrow ? 14 : 16)
            // The window has no title bar, so the traffic lights sit on whatever
            // is at the top left. With column 1 docked that is its own empty
            // corner; once it becomes a drawer it is this header, and the toggle
            // has to clear them rather than hide under them. In native full
            // screen the window has no lights at all, and reserving the room
            // would leave the toggle stranded in the middle of nothing.
            .padding(.leading, showsSidebarToggle && !isFullScreen ? Self.trafficLightWidth : 0)

            axis
        }
        .padding(.top, isNarrow ? 12 : 14)
        .padding(.bottom, isNarrow ? 9 : 10)
    }

    private var title: some View {
        HStack(spacing: 10) {
            if showsSidebarToggle {
                EdenIconButton(systemImage: "sidebar.left", help: "Show or hide the sidebar", size: 28) {
                    ui.isSidebarDrawerOpen.toggle()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(isNarrow ? journal.shortDayTitle : journal.dayTitle)
                    .font(EdenFont.ui(isNarrow ? 17 : 21, .medium))
                    .tracking(-0.02 * (isNarrow ? 17 : 21))
                    .foregroundStyle(EdenColor.textPrimary)
                    .lineLimit(1)
                // One line, never a banner (decision 9), and it steps aside
                // entirely when the header is narrow.
                if let warning = journal.overloadLine, !isNarrow {
                    Text(warning)
                        .font(EdenFont.ui(12))
                        .foregroundStyle(EdenColor.hex(0x77746F))
                        .lineLimit(1)
                }
            }
        }
    }

    /// Day / Week / Month — one segmented control, not a sidebar item and not a
    /// menu. Same control as the task detail's priority (``DaySegmented``).
    private var axis: some View {
        DaySegmented(
            options: TimeAxis.allCases,
            selection: ui.axis,
            fontSize: isNarrow ? 11.5 : 12,
            horizontalPadding: isNarrow ? 10 : 14,
            title: \.title
        ) { ui.axis = $0 }
    }

    @ViewBuilder
    private var trailing: some View {
        if showsDetailToggle {
            EdenIconButton(systemImage: "sidebar.right", help: "Show or hide the side panel", size: 28) {
                ui.isDetailDrawerOpen.toggle()
            }
        }
    }
}
