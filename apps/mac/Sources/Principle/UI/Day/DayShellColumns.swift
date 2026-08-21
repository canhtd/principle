import DesignSystem
import PrincipleCore
import SwiftUI

/// The shell's docked row: column 1, the day, column 3, and the two dividers
/// between them (#18).
///
/// The dividers are not drawn on top of the columns — they *are* the 8 pt of
/// canvas that already sat between them, made grabbable. So a window nobody has
/// dragged anything in is laid out to the point exactly as it was before.
///
/// Every number in the row comes from ``PanelLayout``, which is tested: the
/// widths the panels are drawn at, the width column 2 is left with, and where a
/// drag on either divider lands.
extension DayShell {
    @ViewBuilder
    func columns(width: CGFloat, docksSidebar: Bool, docksDetail: Bool) -> some View {
        let layout = PanelLayout(
            windowWidth: width,
            widths: widths,
            gap: EdenMetric.sidebarInset,
            dayMinimum: DayMetric.dayColumnMinimum,
            docksSidebar: docksSidebar,
            docksDetail: docksDetail
        )
        let shown = layout.shown

        HStack(spacing: 0) {
            if docksSidebar {
                sidebar.frame(width: shown.sidebar)
                divider(.sidebar, help: "Drag to resize the sidebar", in: layout)
            }
            DayColumn(
                journal: journal,
                ui: ui,
                now: now,
                // What the header has to fit in is its own column, not the
                // window: a sidebar dragged wide leaves it just as little room
                // as a narrow window used to (#18).
                isHeaderNarrow: layout.dayWidth < DayMetric.narrowHeaderColumn,
                showsSidebarToggle: !docksSidebar,
                showsDetailToggle: !docksDetail,
                isFullScreen: isFullScreen
            )
            if docksDetail {
                divider(.detail, help: "Drag to resize the panel", in: layout)
                detailColumn.frame(width: shown.detail)
            }
        }
    }

    // MARK: - The dividers

    /// One divider, wired to the panel it resizes.
    ///
    /// The drag begins at the width the divider is *drawn* at, and the widths
    /// are written down only if the hand actually moved one: a plain click on a
    /// divider must leave the stored pair exactly as it found it, or a window
    /// that shrank would quietly destroy the width Danny chose for a wide one.
    private func divider(_ edge: PanelLayout.Edge, help: String, in layout: PanelLayout) -> some View {
        PanelDivider(
            help: help,
            onBegin: { dragStart = layout.dragStart(edge) },
            onDrag: { dx in setWidth(edge, to: layout.dragged(edge, from: dragStart, by: dx)) },
            onEnd: {
                guard width(edge) != dragStart else { return }
                widths.save(to: AppSettings.sharedDefaults())
            }
        )
    }

    private func setWidth(_ edge: PanelLayout.Edge, to value: CGFloat) {
        switch edge {
        case .sidebar: widths.sidebar = value
        case .detail: widths.detail = value
        }
    }

    private func width(_ edge: PanelLayout.Edge) -> CGFloat {
        switch edge {
        case .sidebar: return widths.sidebar
        case .detail: return widths.detail
        }
    }

    // MARK: - The two panels

    @ViewBuilder
    var sidebar: some View {
        EdenPanel {
            SidebarPanel(journal: journal, ui: ui, isFullScreen: isFullScreen)
        }
    }

    /// Column 3, in whichever of its two modes it is in. Both are the same
    /// column: the principle of the day opens it and the bookmarks close it
    /// whatever is between them (#18) — docking Ask Ray swaps the pane, not the
    /// column.
    @ViewBuilder
    var detailColumn: some View {
        EdenPanel {
            if ui.isChatDocked {
                AskRayColumn(journal: journal, session: session, favorites: favorites, ui: ui)
            } else {
                DetailPanel(journal: journal, ui: ui, favorites: favorites)
            }
        }
    }
}
