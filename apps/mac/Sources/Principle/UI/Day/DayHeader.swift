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
            // has to clear them rather than hide under them.
            .padding(.leading, showsSidebarToggle ? Self.trafficLightWidth : 0)

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
    /// menu.
    private var axis: some View {
        HStack(spacing: 0) {
            ForEach(TimeAxis.allCases) { option in
                let isOn = ui.axis == option
                Button { ui.axis = option } label: {
                    Text(option.title)
                        .font(EdenFont.ui(isNarrow ? 11.5 : 12, isOn ? .medium : .regular))
                        .foregroundStyle(isOn ? EdenColor.textPrimary : EdenColor.hex(0x77746F))
                        .padding(.horizontal, isNarrow ? 10 : 14)
                        .padding(.vertical, 5)
                        .background(isOn ? EdenColor.card : .clear, in: .rect(cornerRadius: 6, style: .continuous))
                        .shadow(color: isOn ? EdenColor.black(8) : .clear, radius: 1, y: 1)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(EdenColor.black(5), in: .rect(cornerRadius: EdenRadius.sm, style: .continuous))
        // The pill is its own selected state; a system focus ring on top of it
        // reads as a second, contradictory selection.
        .focusEffectDisabled()
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
