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
                detailColumn().frame(width: shown.detail)
            }
        }
    }

    // MARK: - The dividers

    /// One divider, wired to the panel it resizes.
    ///
    /// The gesture takes hold of the row once, at ``PanelLayout/drag(_:)``, and
    /// every later report is measured against that one frozen copy — never
    /// against `layout`, which is rebuilt from `widths` the drag is itself
    /// changing. Reading the live one is the ratchet ``PanelLayout/Drag``
    /// documents.
    ///
    /// The widths are written down only if the hand actually moved one, and a
    /// drag that came back to where it started puts the stored pair back in
    /// memory as well: the drag works in *drawn* widths, which in a window too
    /// narrow for both are not the stored ones, and leaving the drawn pair
    /// behind would leave memory disagreeing with disk until the next launch.
    private func divider(_ edge: PanelLayout.Edge, help: String, in layout: PanelLayout) -> some View {
        PanelDivider(
            help: help,
            onBegin: { drag = layout.drag(edge) },
            onDrag: { dx in
                guard let drag else { return }
                setWidth(edge, to: drag.width(movedBy: dx))
            },
            onEnd: {
                defer { drag = nil }
                guard let drag else { return }
                guard width(edge) != drag.start else {
                    widths = drag.widthsAtStart
                    return
                }
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
    ///
    /// `isDrawer` is the one place the two part company. Below 1100 pt there is
    /// no column 3 to dock into, so the chat falls back to floating over the
    /// day — and the drawer, which is this same view, would then put a *second*
    /// live `AskRayPanel` on screen driven by the one `SessionViewModel`: two
    /// threads, two composers, one conversation. The drawer therefore always
    /// shows the pane, and the chat stays the floating panel it fell back to.
    @ViewBuilder
    func detailColumn(isDrawer: Bool = false) -> some View {
        EdenPanel {
            if ui.isChatDocked, !isDrawer {
                AskRayColumn(journal: journal, session: session, favorites: favorites, ui: ui)
            } else {
                DetailPanel(journal: journal, ui: ui, favorites: favorites)
            }
        }
    }
}
