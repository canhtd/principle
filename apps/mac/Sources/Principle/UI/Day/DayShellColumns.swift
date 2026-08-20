import DesignSystem
import PrincipleCore
import SwiftUI

/// The shell's docked row: column 1, the day, column 3, and the two dividers
/// between them (#18).
///
/// The dividers are not drawn on top of the columns — they *are* the 8 pt of
/// canvas that already sat between them, made grabbable. So a window nobody has
/// dragged anything in is laid out to the point exactly as it was before.
extension DayShell {
    @ViewBuilder
    func columns(width: CGFloat, docksSidebar: Bool, docksDetail: Bool) -> some View {
        let shown = shownWidths(width: width, docksSidebar: docksSidebar, docksDetail: docksDetail)
        let room = panelRoom(width: width, docksSidebar: docksSidebar, docksDetail: docksDetail)
        let dayWidth = room + DayMetric.dayColumnMinimum
            - (docksSidebar ? shown.sidebar : 0) - (docksDetail ? shown.detail : 0)

        HStack(spacing: 0) {
            if docksSidebar {
                sidebar.frame(width: shown.sidebar)
                PanelDivider(
                    help: "Drag to resize the sidebar",
                    onBegin: { dragStart = widths.sidebar },
                    onDrag: { dx in
                        widths.sidebar = PanelWidths.clamp(
                            dragStart + dx,
                            to: PanelWidths.sidebarLimits,
                            room: docksDetail ? room - shown.detail : room
                        )
                    },
                    onEnd: { widths.save(to: AppSettings.sharedDefaults()) }
                )
            }
            DayColumn(
                journal: journal,
                ui: ui,
                now: now,
                // What the header has to fit in is its own column, not the
                // window: a sidebar dragged wide leaves it just as little room
                // as a narrow window used to (#18).
                isHeaderNarrow: dayWidth < DayMetric.narrowHeaderColumn,
                showsSidebarToggle: !docksSidebar,
                showsDetailToggle: !docksDetail,
                isFullScreen: isFullScreen
            )
            if docksDetail {
                PanelDivider(
                    help: "Drag to resize the panel",
                    onBegin: { dragStart = widths.detail },
                    onDrag: { dx in
                        // The divider is on column 3's *left*, so the pointer
                        // moving left is the column getting wider.
                        widths.detail = PanelWidths.clamp(
                            dragStart - dx,
                            to: PanelWidths.detailLimits,
                            room: docksSidebar ? room - shown.sidebar : room
                        )
                    },
                    onEnd: { widths.save(to: AppSettings.sharedDefaults()) }
                )
                detailColumn.frame(width: shown.detail)
            }
        }
    }

    // MARK: - What the panels are actually drawn at

    /// The room the docked panels may share, once the canvas has had its
    /// margins, each divider its gap, and column 2 its floor.
    func panelRoom(width: CGFloat, docksSidebar: Bool, docksDetail: Bool) -> CGFloat {
        let gaps = (docksSidebar ? 1 : 0) + (docksDetail ? 1 : 0)
        return width - EdenMetric.sidebarInset * CGFloat(2 + gaps) - DayMetric.dayColumnMinimum
    }

    /// A window that shrank under the two stored widths draws them narrower —
    /// it does not overwrite them. Widen the window again and the widths Danny
    /// chose come back, which is what every Mac app does with a split.
    func shownWidths(width: CGFloat, docksSidebar: Bool, docksDetail: Bool) -> PanelWidths {
        let room = panelRoom(width: width, docksSidebar: docksSidebar, docksDetail: docksDetail)
        guard docksSidebar, docksDetail else {
            // One of the two is a drawer: it overlays the day rather than
            // taking width from it, so only the docked one is held to the room.
            return PanelWidths(
                sidebar: docksSidebar
                    ? PanelWidths.clamp(widths.sidebar, to: PanelWidths.sidebarLimits, room: room)
                    : widths.sidebar,
                detail: docksDetail
                    ? PanelWidths.clamp(widths.detail, to: PanelWidths.detailLimits, room: room)
                    : widths.detail
            )
        }
        return widths.fitted(into: room)
    }

    // MARK: - The two panels

    @ViewBuilder
    var sidebar: some View {
        EdenPanel {
            SidebarPanel(journal: journal, ui: ui, isFullScreen: isFullScreen)
        }
    }

    @ViewBuilder
    var detailColumn: some View {
        if ui.isChatDocked {
            AskRayPanel(session: session, favorites: favorites, ui: ui, isDocked: true)
        } else {
            EdenPanel {
                DetailPanel(journal: journal, ui: ui, favorites: favorites)
            }
        }
    }
}
