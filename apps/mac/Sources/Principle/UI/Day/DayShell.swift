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
    @State var isFullScreen = false
    /// How wide the two side panels are, as the last drag left them — read back
    /// out of the defaults on every launch (#18).
    @State var widths = PanelWidths(
        defaults: AppSettings.sharedDefaults(),
        fallback: DayMetric.defaultWidths
    )
    /// The width the divider being dragged started from. Every report of a drag
    /// is measured against that one number rather than against the last frame,
    /// which is what keeps a fast drag from drifting.
    @State var dragStart: CGFloat = 0

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

                // The dividers are the 8 pt of canvas between the columns, so
                // the row itself has no spacing of its own to add (#18).
                columns(width: width, docksSidebar: docksSidebar, docksDetail: docksDetail)
                    .padding(EdenMetric.sidebarInset)

                drawers(docksSidebar: docksSidebar, docksDetail: docksDetail, size: proxy.size)
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
            // morning rather than yesterday's grid — and a day Danny opened to
            // review must stay where he put it (#17).
            journal.advanceIfDayRolledOver(at: tick)
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

    // MARK: - Drawers (decision 10)

    @ViewBuilder
    private func drawers(docksSidebar: Bool, docksDetail: Bool, size: CGSize) -> some View {
        let sidebarOpen = !docksSidebar && ui.isSidebarDrawerOpen
        let detailOpen = !docksDetail && ui.isDetailDrawerOpen
        let height = size.height - EdenMetric.sidebarInset * 2
        // A drawer is the same panel, at the width it was last dragged to — but
        // never wider than the window it is sliding over.
        let ceiling = size.width - EdenMetric.sidebarInset * 2

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
                .frame(width: min(widths.sidebar, ceiling), height: height)
                .edenFloatShadow(opacity: 14)
                .padding(EdenMetric.sidebarInset)
                .transition(.move(edge: .leading))
        }
        if detailOpen {
            detailColumn
                .frame(width: min(widths.detail, ceiling), height: height)
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
