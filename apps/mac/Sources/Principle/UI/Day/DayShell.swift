import DesignSystem
import PrincipleCore
import SwiftUI

/// The whole screen: Eden's canvas with two panels floating on it and the day
/// between them.
///
/// The shell is fluid (decision 10). Only the side panels carry a width; column
/// 2 takes whatever is left and the grid scrolls inside it. Below 1100 pt column
/// 3 becomes a drawer, below 900 pt column 1 does too — an open drawer is an
/// overlay, so column 2 never gives up the width it had.
struct DayShell: View {
    @State var journal: JournalModel
    @Bindable var session: SessionViewModel
    let favorites: FavoritesModel
    @State var ui = DayShellState()
    /// Ticks the current-time line along, and rolls the screen over at midnight.
    @State var now = Date()
    /// Native full screen has no traffic lights, so the panels that were
    /// holding room for them give it back. `WindowChrome` is what knows.
    @State private var isFullScreen = false

    init(repoURL: URL, session: SessionViewModel, favorites: FavoritesModel) {
        _journal = State(initialValue: JournalModel(repoURL: repoURL))
        self.session = session
        self.favorites = favorites
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let docksSidebar = width >= DayMetric.sidebarDrawer
            let docksDetail = width >= DayMetric.detailDrawer

            ZStack(alignment: .topLeading) {
                EdenColor.canvas
                EdenPageGradient()

                HStack(spacing: EdenMetric.sidebarInset) {
                    if docksSidebar {
                        sidebar.frame(width: EdenMetric.sidebarWidth)
                    }
                    DayColumn(
                        journal: journal,
                        ui: ui,
                        now: now,
                        isHeaderNarrow: width < DayMetric.narrowHeader,
                        showsSidebarToggle: !docksSidebar,
                        showsDetailToggle: !docksDetail,
                        isFullScreen: isFullScreen
                    )
                    if docksDetail {
                        detailColumn.frame(width: DayMetric.detailWidth)
                    }
                }
                .padding(EdenMetric.sidebarInset)

                drawers(docksSidebar: docksSidebar, docksDetail: docksDetail, height: proxy.size.height)
                chatLayer(size: proxy.size, docksDetail: docksDetail)
            }
            .onChange(of: width) { _, new in ui.syncDrawers(width: new) }
            // The excerpt popover is capped against the window, and a popover
            // is its own window — so the shell is what has to measure it.
            .onChange(of: proxy.size.height, initial: true) { _, new in ui.windowHeight = new }
        }
        .background(EdenColor.canvas)
        .onReceive(Self.clock) { tick in
            now = tick
            // Left open overnight, the app must be showing the new day in the
            // morning rather than yesterday's grid.
            if journal.isToday == false, Calendar.current.isDateInToday(tick), journal.selectionIsStale(before: tick) {
                journal.showToday()
            }
        }
        // The lights belong inside column 1's panel, not on its corner.
        .edenWindowChrome(isFullScreen: $isFullScreen)
        .onExitCommand { ui.dismissTopmost() }
        // Delete on a selected block, from wherever the key lands in the window
        // — the grid has no first responder of its own to hang it off.
        .onDeleteCommand(perform: deleteSelection)
        .onAppear(perform: applyLaunchState)
    }

    /// What the Delete key does to the block that is selected: the same thing
    /// the detail pane's `Delete task` does, which asks nothing first — the
    /// journal is an append-only log, so the row is still in `tasks.jsonl`.
    ///
    /// A field being typed into swallows the key long before this sees it; the
    /// two states that only *look* like text — a category being renamed, a new
    /// one being named — are checked, because losing a task to a stray Backspace
    /// while naming something else would be unforgivable.
    private func deleteSelection() {
        guard ui.renamingCategoryID == nil, !ui.isAddingCategory, let id = ui.selectedTaskID else { return }
        journal.deleteTask(id: id)
        ui.select(taskID: nil)
    }

    /// Once a minute: the red line only ever moves by a pixel, and a second-by
    /// second timer would redraw the whole grid for nothing.
    private static let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // MARK: - The columns

    @ViewBuilder
    private var sidebar: some View {
        EdenPanel {
            SidebarPanel(journal: journal, ui: ui, favorites: favorites,
                         isFullScreen: isFullScreen)
        }
    }

    @ViewBuilder
    private var detailColumn: some View {
        if ui.isChatDocked {
            AskRayPanel(session: session, favorites: favorites, ui: ui, isDocked: true)
        } else {
            EdenPanel {
                DetailPanel(journal: journal, ui: ui)
            }
        }
    }

    // MARK: - Drawers (decision 10)

    @ViewBuilder
    private func drawers(docksSidebar: Bool, docksDetail: Bool, height: CGFloat) -> some View {
        let sidebarOpen = !docksSidebar && ui.isSidebarDrawerOpen
        let detailOpen = !docksDetail && ui.isDetailDrawerOpen

        if sidebarOpen || detailOpen {
            // A click off an open drawer closes it, the way a drawer closes.
            Color.black.opacity(0.001)
                .contentShape(.rect)
                .onTapGesture {
                    ui.isSidebarDrawerOpen = false
                    ui.isDetailDrawerOpen = false
                }
        }
        if sidebarOpen {
            sidebar
                .frame(width: EdenMetric.sidebarWidth, height: height - EdenMetric.sidebarInset * 2)
                .edenFloatShadow(opacity: 14)
                .padding(EdenMetric.sidebarInset)
                .transition(.move(edge: .leading))
        }
        if detailOpen {
            detailColumn
                .frame(width: DayMetric.detailWidth, height: height - EdenMetric.sidebarInset * 2)
                .edenFloatShadow(opacity: 14)
                .padding(EdenMetric.sidebarInset)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .transition(.move(edge: .trailing))
        }
    }

    // MARK: - Ask Ray (decision 8)

    @ViewBuilder
    private func chatLayer(size: CGSize, docksDetail: Bool) -> some View {
        // Docked, the chat is column 3 and has already been drawn there — unless
        // the window is too narrow to have a column 3 at all, in which case it
        // falls back to floating rather than disappearing.
        let isDockedInline = ui.isChatDocked && docksDetail
        if ui.isChatOpen, !isDockedInline {
            AskRayPanel(session: session, favorites: favorites, ui: ui, isDocked: false)
                .frame(
                    width: min(DayMetric.chatWidth, size.width - DayMetric.chatMargin * 2),
                    height: min(
                        size.height < DayMetric.chatShortWindow ? DayMetric.chatShortHeight : DayMetric.chatHeight,
                        size.height - DayMetric.chatMargin * 2
                    )
                )
                .padding(DayMetric.chatMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        } else if !ui.isChatOpen {
            AskRayBubble { ui.openChat() }
                .padding(DayMetric.chatMargin)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
    }
}
